package parcel;

import Types.GraphicsBackend;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.ds.ReadOnlyArray;
import sys.io.abstractions.IFileSystem;
import sys.io.abstractions.concrete.FileSystem;
import uk.aidanlee.flurry.api.core.Unit;
import uk.aidanlee.flurry.api.core.Result;
import uk.aidanlee.flurry.api.stream.ParcelOutput;
import uk.aidanlee.flurry.api.stream.Compression;
import uk.aidanlee.flurry.api.stream.ImageFormat;
import uk.aidanlee.flurry.api.resources.Resource;
import parcel.Types;
import parcel.GdxParser;
import Types.Project;

using Utils;
using Safety;
using Lambda;

class Packer
{
    final fs : IFileSystem;

    final proc : Proc;

    /**
     * Temp location used to store intermediate shader data.
     */
    final tempAssets : String;

    /**
     * Temp location used to store all generated font images and json.
     */
    final tempFonts : String;

    /**
     * Temp location used to store all exported sprite sheets and json.
     */
    final tempSprites : String;

    /**
     * Temp location used to store all parcels.
     */
    final tempParcels : String;

    final tempShaders : String;

    /**
     * Directory where this platforms pre-compiled tools are found.
     */
    final toolsDir : String;

    /**
     * Map of all pre-processed resources (texts, bytes, and shaders)
     * Keyed by the resources unique ID.
     */
    final prepared : Map<String, Resource>;

    final shaders : Shaders;

    public function new(_project : Project, _gpu : GraphicsBackend, _fs : IFileSystem = null, _proc : Proc = null)
    {
        fs          = _fs.or(new FileSystem());
        proc        = _proc.or(new Proc());
        tempFonts   = _project.tempFonts();
        tempSprites = _project.tempSprites();
        tempAssets  = _project.tempAssets();
        tempParcels = _project.tempParcels();
        tempShaders = _project.tempShaders();
        toolsDir    = _project.toolPath();
        prepared    = [];
        shaders     = new Shaders(toolsDir, proc, fs, _gpu);

        fs.directory.create(tempFonts);
        fs.directory.create(tempAssets);
        fs.directory.create(tempSprites);
        fs.directory.create(tempParcels);
        fs.directory.create(tempShaders);
    }

    public function create(_path : String) : Result<Array<{ name : String, file : String }>, String>
    {
        final assets      = parse(fs.file.getText(_path));
        final baseDir     = Path.directory(_path);
        final parcelBytes = [];

        // Shaders, text, and bytes can be pre-processed and the resources stored

        for (shader in assets.assets.shaders)
        {
            switch shaders.compile(baseDir, tempShaders, shader)
            {
                case Success(data):
                    prepared[shader.id] = data;
                case Failure(message):
                    return Failure(message);
            }
        }

        for (text in assets.assets.texts)
        {
            prepared[text.id] = new TextResource(text.id, fs.file.getText(Path.join([ baseDir, text.path ])));
        }

        for (bytes in assets.assets.bytes)
        {
            prepared[bytes.id] = new BytesResource(bytes.id, fs.file.getBytes(Path.join([ baseDir, bytes.path ])));
        }

        // Fonts can also be pre-generated (but not as a final resource), their images and json data are stored in a separate font cache
        // `temp/fonts` relative to the projects output directory.

        for (font in assets.assets.fonts)
        {
            final tool = Path.join([ toolsDir, Utils.msdfAtlasExecutable() ]);
            final out  = Path.join([ tempFonts, font.id ]);

            switch proc.run(tool, [
                '-font',
                Path.join([ baseDir, font.path ]),
                '-type', 'msdf',
                '-format', 'png',
                '-imageout', out + '.png',
                '-json', out + '.json',
                '-size', '48' ])
            {
                case Failure(message): return Failure(message);
                case _:
            }
        }

        for (sprite in assets.assets.sprites)
        {
            final tool    = Utils.asepriteExecutable();
            final outPng  = Path.join([ tempSprites, sprite.id + '.png' ]);
            final outJson = Path.join([ tempSprites, sprite.id + '.json' ]);

            switch proc.run(tool, [
                '--batch',
                Path.join([ baseDir, sprite.path ]),
                '--sheet', outPng,
                '--data', outJson,
                '--format', 'json-array',
                '--filename-format', '{frame}',
                '--list-tags' ])
            {
                case Failure(message): Failure(message);
                case _:
            }
        }

        // Images, sheets, and fonts can't be pre-created into resources as they are packed together based on the parcel.

        for (parcel in assets.parcels)
        {
            final deflate     = parcel!.options!.compression.or(6);
            final compression = if (deflate == 0) None else Deflate(deflate - 0, 32000000);
            final file        = Path.join([ tempParcels, parcel.name ]);
            final stream      = new ParcelOutput(fs.file.write(file), compression);

            if (parcel.images != null || parcel.fonts != null || parcel.sheets != null || parcel.sprites != null)
            {
                switch packImages(
                    baseDir,
                    parcel,
                    stream,
                    assets.assets.images,
                    assets.assets.sheets,
                    assets.assets.fonts,
                    assets.assets.sprites,
                    parcel.options.or({
                        pageMaxWidth     : 4096,
                        pageMaxHeight    : 4096,
                        pagePadX         : 0,
                        pagePadY         : 0,
                        compression      : 6,
                        format           : 'png'
                    }))
                {
                    case Failure(message): return Failure(message);
                    case _:
                }
            }

            for (id in parcel.texts.or([]))
            {
                if (prepared.exists(id))
                {
                    stream.add(SerialisedResource(prepared[id].sure()));
                }
            }
            for (id in parcel.bytes.or([]))
            {
                if (prepared.exists(id))
                {
                    stream.add(SerialisedResource(prepared[id].sure()));
                }
            }
            for (id in parcel.shaders.or([]))
            {
                if (prepared.exists(id))
                {
                    stream.add(SerialisedResource(prepared[id].sure()));
                }
            }

            stream.commit();
            stream.close();

            parcelBytes.push({
                name : parcel.name,
                file : file
            });

            clean(tempAssets);
        }

        clean(tempAssets);
        clean(tempFonts);
        clean(tempSprites);

        return Success(parcelBytes);
    }

    /**
     * Parse the provided text into a assets json structure.
     * @param _text Text to parse.
     * @return JsonDefinition
     */
    function parse(_text : String) : JsonDefinition
        return tink.Json.parse(_text);

    /**
     * Pack all image related resources in the parcel and create frame resources for them.
     * @param _baseDir Base directory to prepend to asset paths
     * @param _parcel The parcel to pack.
     * @param _images All image resources in this project.
     * @param _sheets All image sheet resources in this project.
     * @param _fonts All font resources in this project.
     * @param _options Options for how the texture pages should be generated.
     * @return Array<Resource>
     */
    function packImages(
        _baseDir : String,
        _parcel : JsonParcel,
        _stream : ParcelOutput,
        _images : Array<JsonResource>,
        _sheets : Array<JsonResource>,
        _fonts : Array<JsonResource>,
        _sprites : Array<JsonResource>,
        _options : JsonPackingOptions) : Result<Unit, String>
    {
        final atlases = [];
        final bmfonts = [];
        final sprites = [];

        for (id in _parcel.images.or([]))
        {
            _images
                .find(image -> image.id == id)
                .run(image -> fs.file.copy(Path.join([ _baseDir, image.path ]), Path.join([ tempAssets, image.id + '.png' ])));
        }
        for (id in _parcel.sheets.or([]))
        {
            _sheets
                .find(sheet -> sheet.id == id)
                .run(sheet -> {
                    final path  = new Path(Path.join([ _baseDir, sheet.path ]));
                    final atlas = GdxParser.parse(path.toString(), fs);

                    for (page in atlas)
                    {
                        fs.file.copy(
                            Path.join([ path.dir.sure(), page.image.toString() ]),
                            Path.join([ tempAssets, page.image.toString() ]));
                    }

                    atlases.push(atlas);
                });
        }
        for (id in _parcel.fonts.or([]))
        {
            _fonts
                .find(font -> font.id == id)
                .run(font -> {
                    final path = new Path(font.id);
                    path.dir = tempFonts;
                    path.ext = 'json';

                    final bmfont : JsonFontDefinition = tink.Json.parse(fs.file.getText(path.toString()));

                    final image = font.id + '.png';

                    fs.file.copy(
                        Path.join([ tempFonts, image ]),
                        Path.join([ tempAssets, image ]));

                    bmfonts.push({ id : font.id, font : bmfont });
                });
        }
        for (id in _parcel.sprites.or([]))
        {
            _sprites
                .find(sprite -> sprite.id == id)
                .run(sprite -> {
                    final path = new Path(sprite.id);
                    path.dir = tempSprites;
                    path.ext = 'json';

                    final json : JsonSprite = tink.Json.parse(fs.file.getText(path.toString()));

                    final image = sprite.id + '.png';

                    fs.file.copy(
                        Path.join([ tempSprites, image ]),
                        Path.join([ tempAssets, image ]));

                    sprites.push({ id : sprite.id, sprite : json });
                });
        }

        // Pack all of our collected images

        switch proc.run(Path.join([ toolsDir, Utils.atlasCreatorExecutable() ]), [
            '--directory', tempAssets,
            '--output', tempAssets,
            '--name', _parcel.name,
            '--width', Std.string(_options.pageMaxWidth),
            '--height', Std.string(_options.pageMaxHeight),
            '--x-pad', Std.string(_options.pagePadX),
            '--y-pad', Std.string(_options.pagePadY),
            '--threads', '4',
            '--format', _options.format
        ])
        {
            case Failure(message): return Failure('Parcel exited with a non zero code of $message');
            case _:
        }

        // Read the packed result

        final atlas : JsonAtlas = tink.Json.parse(fs.file.getText(Path.join([ tempAssets, '${ _parcel.name }.json' ])));

        // Create images for all unique pages

        for (page in atlas.pages)
        {
            final imgPath = new Path(Path.join([ tempAssets, page.image ]));
            final format  = switch imgPath.ext
            {
                case 'jpeg', 'jpg': Jpeg;
                case 'png': Png;
                case 'raw': RawBGRA;
                case other:
                    _stream.close();
                    return Failure('Unsupported image format $other');
            }

            _stream.add(ImageData(imageBytes(imgPath), format, page.width, page.height, page.image));
        }

        // Search for all of our composited images within the pages

        for (id in _parcel.images.or([]))
        {
            for (page in atlas.pages)
            {
                page
                    .packed
                    .find(section -> section.file == id)
                    .run(section -> {
                        _stream.add(SerialisedResource(new ImageFrameResource(
                            id,
                            page.image,
                            section.x,
                            section.y,
                            section.width,
                            section.height,
                            section.x / page.width,
                            section.y / page.height,
                            (section.x + section.width) / page.width,
                            (section.y + section.height) / page.height)));
                    });
            }
        }

        for (gdxAtlas in atlases)
        {
            for (page in gdxAtlas)
            {
                switch findSection(page.image.file, atlas.pages)
                {
                    case Success(found):
                        for (section in page.sections)
                        {
                            _stream.add(SerialisedResource(new ImageFrameResource(
                                section.name,
                                found.page.image,
                                found.section.x + section.x,
                                found.section.y + section.y,
                                section.width,
                                section.height,
                                (found.section.x + section.x) / found.page.width,
                                (found.section.y + section.y) / found.page.height,
                                (found.section.x + section.x + section.width) / found.page.width,
                                (found.section.y + section.y + section.height) / found.page.height)));
                        }
        
                        continue;
                    case Failure(message): return Failure(message);
                }
            }
        }

        for (bmfont in bmfonts)
        {
            switch findSection(bmfont.id, atlas.pages)
            {
                case Success(found):
                    final chars = new Map<Int, Character>();

                    for (char in bmfont.font.glyphs)
                    {
                        if (char.atlasBounds != null && char.planeBounds != null)
                        {
                            // glyph atlas coords are packed bottom left origin so we transform to top left origin
                            final ax = char.atlasBounds.left;
                            final ay = (bmfont.font.atlas.height - char.atlasBounds.top);
                            final aw = char.atlasBounds.right - char.atlasBounds.left;
                            final ah = (bmfont.font.atlas.height - char.atlasBounds.bottom) - (bmfont.font.atlas.height - char.atlasBounds.top);
        
                            final pLeft   = char.planeBounds.left;
                            final pTop    = 1 - char.planeBounds.top;
                            final pRight  = char.planeBounds.right;
                            final pBottom = 1 - char.planeBounds.bottom;
        
                            chars[char.unicode] = new Character(
                                pLeft,
                                pTop,
                                pRight,
                                pBottom,
                                char.advance,
                                (found.section.x + ax) / found.page.width,
                                (found.section.y + ay) / found.page.height,
                                (found.section.x + ax + aw) / found.page.width,
                                (found.section.y + ay + ah) / found.page.height);
                        }
                        else
                        {
                            chars[char.unicode] = new Character(0, 0, 0, 0, char.advance, 0, 0, 1, 1);
                        }
                    }
        
                    _stream.add(SerialisedResource(new FontResource(
                        found.section.file,
                        found.page.image,
                        chars,
                        bmfont.font.metrics.lineHeight,
                        found.section.x,
                        found.section.y,
                        found.section.width,
                        found.section.height,
                        found.section.x / found.page.width,
                        found.section.y / found.page.height,
                        (found.section.x + found.section.width) / found.page.width,
                        (found.section.y + found.section.height) / found.page.height)));
        
                    continue;
                case Failure(message): return Failure(message);
            }
        }

        for (sprite in sprites)
        {
            switch findSection(sprite.id, atlas.pages)
            {
                case Success(found):
                    final sets = new Map<String, Array<SpriteFrameResource>>();

                    for (tag in sprite.sprite.meta.frameTags)
                    {
                        sets[tag.name] = [ for (i in tag.from...tag.to + 1) {
                            final frame = sprite.sprite.frames.find(f -> Std.parseInt(f.filename) == i).sure();
                            final x     = found.section.x + frame.frame.x;
                            final y     = found.section.y + frame.frame.y;

                            new SpriteFrameResource(
                                frame.frame.w,
                                frame.frame.h,
                                frame.duration,
                                x / found.page.width,
                                y / found.page.height,
                                (x + frame.frame.w) / found.page.width,
                                (y + frame.frame.h) / found.page.height);
                        } ];
                    }

                    _stream.add(SerialisedResource(new SpriteResource(
                        found.section.file,
                        found.page.image,
                        found.section.x,
                        found.section.y,
                        found.section.width,
                        found.section.height,
                        found.section.x / found.page.width,
                        found.section.y / found.page.height,
                        (found.section.x + found.section.width) / found.page.width,
                        (found.section.y + found.section.height) / found.page.height,
                        sets)));
                case Failure(message): return Failure(message);
            }
        }

        return Success(Unit.value);
    }

    /**
     * Find an atlas section and the page it is within.
     * @param _name Name of the section to search for.
     * @param _pages Structure containing the page and section.
     */
    function findSection(_name : String, _pages : ReadOnlyArray<JsonAtlasPage>) : Result<{ page : JsonAtlasPage, section : JsonAtlasImage }, String>
    {
        for (page in _pages)
        {
            final section = page
                .packed
                .find(section -> section.file == _name);

            if (section != null)
            {
                return Success({ page : page, section : section.sure() });
            }
        }

        return Failure('Unable to find section for $_name');
    }

    /**
     * Get the BGRA bytes data of a png.
     * @param _path Path to the image.
     * @return Bytes
     */
    function imageBytes(_path : Path) : Bytes
    {
        return fs.file.getBytes(_path.toString());
    }

    /**
     * Remove all files and directories from the provided path.
     * However, the provided directory itself is not removed.
     * @param _dir Directory path to clean.
     */
    function clean(_dir : String)
    {
        for (item in fs.directory.read(_dir))
        {
            final path = Path.join([ _dir, item ]);

            if (fs.directory.isDirectory(path))
            {
                fs.directory.remove(path);
            }
            else
            {
                fs.file.remove(path);
            }
        }
    }
}