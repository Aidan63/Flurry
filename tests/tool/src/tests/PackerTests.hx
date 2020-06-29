package tests;

import parcel.Types.JsonAtlas;
import parcel.Types.JsonAtlasPage;
import parcel.Types.JsonSprite;
import parcel.GdxParser.GdxSection;
import parcel.GdxParser.GdxPage;
import parcel.Types.JsonFontDefinition;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.zip.Uncompress;
import hxbit.Serializer;
import Types.Unit;
import Types.Result;
import Types.Project;
import parcel.Packer;
import parcel.Types.JsonDefinition;
import parcel.Types.JsonShaderDefinition;
import sys.io.abstractions.mock.MockFileData;
import sys.io.abstractions.mock.MockFileSystem;
import uk.aidanlee.flurry.api.resources.Resource.ImageFrameResource;
import uk.aidanlee.flurry.api.resources.Resource.ParcelResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.SpriteResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.FontResource;
import buddy.BuddySuite;
import mockatoo.Mockatoo.*;

using mockatoo.Mockatoo;
using buddy.Should;
using Lambda;

class PackerTests extends BuddySuite
{
    public function new()
    {
        describe('Parcel Generation', {
            describe('shaders', {
                it('will invoke fxc to compile hlsl shaders', {
                    final shader : JsonShaderDefinition = { textures : [ ], blocks : [] }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader',
                                    path : 'definition.json',
                                    hlsl : {
                                        vertex   : 'vert.hlsl',
                                        fragment : 'frag.hlsl',
                                        compiled : true
                                    }
                                }
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader' ] }
                        ]
                    }
                    final project = project();
                    final fs      = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert.hlsl'       => MockFileData.fromText('vert'),
                        'frag.hlsl'       => MockFileData.fromText('frag')
                    ], []);
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    Mockatoo.when(proc.run('fxc', anyIterator)).thenCall(f -> {
                        // Instead of actually calling fxc we'll dump some dummy files according to the args so they can be read back
                        final args  = (cast f[1] : Array<String>);
                        final stage = args[1];
                        final path  = args[5];

                        fs.file.writeText(path, stage);

                        return Success(Unit.value);
                    });

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            data.length.should.be(1);
                            data[0].name.should.be('parcel');

                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);
                            parcel.name.should.be('parcel');
                            parcel.depends.length.should.be(0);
                            parcel.assets.length.should.be(1);
                            parcel.assets.count(r -> r.id == 'shader' && r.type == Shader).should.be(1);

                            // Check our compiled hlsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader' && r.type == Shader) : ShaderResource);
                            resource.ogl3.should.be(null);
                            resource.ogl4.should.be(null);
                            resource.hlsl.compiled.should.be(true);
                            resource.hlsl.vertex.compare(Bytes.ofString('vs_5_0')).should.be(0);
                            resource.hlsl.fragment.compare(Bytes.ofString('ps_5_0')).should.be(0);
                        case Failure(message):
                            fail(message);
                    }
                });
                it('will invoke glslangValidator to compile glsl shaders', {
                    final shader : JsonShaderDefinition = { textures : [ ], blocks : [] }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader',
                                    path : 'definition.json',
                                    ogl4 : {
                                        vertex   : 'vert.glsl',
                                        fragment : 'frag.glsl',
                                        compiled : true
                                    }
                                }
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader' ] }
                        ]
                    }
                    final project = project();
                    final fs      = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert.glsl'       => MockFileData.fromText('vert'),
                        'frag.glsl'       => MockFileData.fromText('frag')
                    ], []);
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    Mockatoo.when(proc.run('glslangValidator', anyIterator)).thenCall(f -> {
                        // Instead of actually calling glslangValidator we'll dump some dummy files according to the args so they can be read back
                        final args  = (cast f[1] : Array<String>);
                        final stage = args[2];
                        final path  = args[5];

                        fs.file.writeText(path, stage);

                        return Success(Unit.value);
                    });

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            data.length.should.be(1);
                            data[0].name.should.be('parcel');

                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);
                            parcel.name.should.be('parcel');
                            parcel.depends.length.should.be(0);
                            parcel.assets.length.should.be(1);
                            parcel.assets.count(r -> r.id == 'shader' && r.type == Shader).should.be(1);

                            // Check our compiled glsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader' && r.type == Shader) : ShaderResource);
                            resource.hlsl.should.be(null);
                            resource.ogl3.should.be(null);
                            resource.ogl4.compiled.should.be(true);
                            resource.ogl4.vertex.compare(Bytes.ofString('vert')).should.be(0);
                            resource.ogl4.fragment.compare(Bytes.ofString('frag')).should.be(0);
                        case Failure(message):
                            fail(message);
                    }
                });
                it('will pass hlsl shaders as text if they dont need compiling', {
                    final shader : JsonShaderDefinition = { textures : [ ], blocks : [] }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader',
                                    path : 'definition.json',
                                    hlsl : {
                                        vertex   : 'vert.hlsl',
                                        fragment : 'frag.hlsl',
                                        compiled : false
                                    }
                                }
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader' ] }
                        ]
                    }
                    final project = project();
                    final fs      = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert.hlsl'       => MockFileData.fromText('plain text vert'),
                        'frag.hlsl'       => MockFileData.fromText('plain text frag')
                    ], []);
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            Mockatoo.verify(proc.run('fxc', anyIterator), 0);

                            data.length.should.be(1);
                            data[0].name.should.be('parcel');

                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);
                            parcel.name.should.be('parcel');
                            parcel.depends.length.should.be(0);
                            parcel.assets.length.should.be(1);
                            parcel.assets.count(r -> r.id == 'shader' && r.type == Shader).should.be(1);

                            // Check our compiled hlsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader' && r.type == Shader) : ShaderResource);
                            resource.ogl3.should.be(null);
                            resource.ogl4.should.be(null);
                            resource.hlsl.compiled.should.be(false);
                            resource.hlsl.vertex.compare(Bytes.ofString('plain text vert')).should.be(0);
                            resource.hlsl.fragment.compare(Bytes.ofString('plain text frag')).should.be(0);
                        case Failure(message):
                            fail(message);
                    }
                });
                it('will pass glsl shaders as text if they dont need compiling', {
                    final shader : JsonShaderDefinition = { textures : [ ], blocks : [] }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader',
                                    path : 'definition.json',
                                    ogl4 : {
                                        vertex   : 'vert.glsl',
                                        fragment : 'frag.glsl',
                                        compiled : false
                                    }
                                }
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader' ] }
                        ]
                    }
                    final project = project();
                    final fs      = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert.glsl'       => MockFileData.fromText('plain text vert'),
                        'frag.glsl'       => MockFileData.fromText('plain text frag')
                    ], []);
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            Mockatoo.verify(proc.run('glslangValidator', anyIterator), 0);

                            data.length.should.be(1);
                            data[0].name.should.be('parcel');

                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);
                            parcel.name.should.be('parcel');
                            parcel.depends.length.should.be(0);
                            parcel.assets.length.should.be(1);
                            parcel.assets.count(r -> r.id == 'shader' && r.type == Shader).should.be(1);

                            // Check our compiled glsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader' && r.type == Shader) : ShaderResource);
                            resource.hlsl.should.be(null);
                            resource.ogl3.should.be(null);
                            resource.ogl4.compiled.should.be(false);
                            resource.ogl4.vertex.compare(Bytes.ofString('plain text vert')).should.be(0);
                            resource.ogl4.fragment.compare(Bytes.ofString('plain text frag')).should.be(0);
                        case Failure(message):
                            fail(message);
                    }
                });
                it('will not attempt to compile glsl 3.3 shaders', {
                    final shader : JsonShaderDefinition = { textures : [ ], blocks : [] }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader1',
                                    path : 'definition.json',
                                    ogl3 : {
                                        vertex   : 'vert1.glsl',
                                        fragment : 'frag1.glsl',
                                        compiled : false
                                    }
                                },
                                {
                                    id   : 'shader2',
                                    path : 'definition.json',
                                    ogl3 : {
                                        vertex   : 'vert2.glsl',
                                        fragment : 'frag2.glsl',
                                        compiled : true
                                    }
                                }
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader1', 'shader2' ] }
                        ]
                    }
                    final project = project();
                    final fs      = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert1.glsl'      => MockFileData.fromText('plain text vert1'),
                        'frag1.glsl'      => MockFileData.fromText('plain text frag1'),
                        'vert2.glsl'      => MockFileData.fromText('plain text vert2'),
                        'frag2.glsl'      => MockFileData.fromText('plain text frag2')
                    ], []);
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            Mockatoo.verify(proc.run('glslangValidator', anyIterator), 0);

                            data.length.should.be(1);
                            data[0].name.should.be('parcel');

                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);
                            parcel.name.should.be('parcel');
                            parcel.depends.length.should.be(0);
                            parcel.assets.length.should.be(2);
                            parcel.assets.count(r -> r.id == 'shader1' && r.type == Shader).should.be(1);
                            parcel.assets.count(r -> r.id == 'shader2' && r.type == Shader).should.be(1);

                            // Check our compiled glsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader1' && r.type == Shader) : ShaderResource);
                            resource.hlsl.should.be(null);
                            resource.ogl4.should.be(null);
                            resource.ogl3.compiled.should.be(false);
                            resource.ogl3.vertex.compare(Bytes.ofString('plain text vert1')).should.be(0);
                            resource.ogl3.fragment.compare(Bytes.ofString('plain text frag1')).should.be(0);

                            final resource = (cast parcel.assets.find(r -> r.id == 'shader2' && r.type == Shader) : ShaderResource);
                            resource.hlsl.should.be(null);
                            resource.ogl4.should.be(null);
                            resource.ogl3.compiled.should.be(false);
                            resource.ogl3.vertex.compare(Bytes.ofString('plain text vert2')).should.be(0);
                            resource.ogl3.fragment.compare(Bytes.ofString('plain text frag2')).should.be(0);
                        case Failure(message):
                            fail(message);
                    }
                });
                it('will produce a structure matching the shaders definition', {
                    final shader : JsonShaderDefinition = {
                        textures : [ 'texture1', 'texture2' ],
                        blocks   : [
                            {
                                name : 'matrices',
                                binding : 0,
                                values : [
                                    { type : Matrix4, name : 'projection' },
                                    { type : Matrix4, name : 'view' },
                                    { type : Matrix4, name : 'model' }
                                ]
                            },
                            {
                                name : 'colours',
                                binding : 1,
                                values : [
                                    { type : Vector4, name : 'colour' }
                                ]
                            }
                        ]
                    }
                    final assets : JsonDefinition = {
                        assets : {
                            bytes : [],
                            texts : [],
                            fonts : [],
                            images : [],
                            sheets : [],
                            sprites : [],
                            shaders : [
                                {
                                    id   : 'shader',
                                    path : 'definition.json',
                                    ogl3 : {
                                        vertex   : 'vert.glsl',
                                        fragment : 'frag.glsl',
                                        compiled : false
                                    }
                                },
                            ]
                        },
                        parcels : [ 
                            { name : 'parcel', depends : [], shaders : [ 'shader' ] }
                        ]
                    }
                    final fs = new MockFileSystem([
                        'assets.json'     => MockFileData.fromText(tink.Json.stringify(assets)),
                        'definition.json' => MockFileData.fromText(tink.Json.stringify(shader)),
                        'vert.glsl'       => MockFileData.fromText('plain text vert'),
                        'frag.glsl'       => MockFileData.fromText('plain text frag')
                    ], []);
                    final project = project();
                    final proc    = mock(Proc);
                    final packer  = new Packer(project, fs, proc);

                    switch packer.create('assets.json')
                    {
                        case Success(data):
                            // Unpack the serialised bytes.
                            final parcel = unpack(data[0].bytes);

                            // Check our compiled glsl shader
                            final resource = (cast parcel.assets.find(r -> r.id == 'shader' && r.type == Shader) : ShaderResource);

                            resource.layout.textures.length.should.be(2);
                            resource.layout.textures[0].should.be('texture1');
                            resource.layout.textures[1].should.be('texture2');

                            resource.layout.blocks.length.should.be(2);
                            resource.layout.blocks[0].name.should.be('matrices');
                            resource.layout.blocks[0].binding.should.be(0);
                            resource.layout.blocks[0].values.length.should.be(3);
                            resource.layout.blocks[0].values.count(v -> v.name == 'projection' && v.type == Matrix4).should.be(1);
                            resource.layout.blocks[0].values.count(v -> v.name == 'view' && v.type == Matrix4).should.be(1);
                            resource.layout.blocks[0].values.count(v -> v.name == 'model' && v.type == Matrix4).should.be(1);
                            resource.layout.blocks[1].values.count(v -> v.name == 'colour' && v.type == Vector4).should.be(1);
                        case Failure(message):
                            fail(message);
                    }
                });
            });
            it('will call msdf-atlas-gen to generate font sheets', {
                final assets : JsonDefinition = {
                    assets : {
                        bytes : [],
                        texts : [],
                        fonts : [
                            { id : 'custom_font', path : 'font.ttf' }
                        ],
                        images : [],
                        sheets : [],
                        sprites : [],
                        shaders : []
                    },
                    parcels : [ 
                        { name : 'parcel', depends : [], fonts : [ 'custom_font' ] }
                    ]
                }
                final fs = new MockFileSystem([
                    'assets.json' => MockFileData.fromText(tink.Json.stringify(assets))
                ], []);
                final project = project();
                final proc    = mock(Proc);
                final packer  = new Packer(project, fs, proc);

                // Intercept calls to msdf-atlas-gen and place a pre-defined json and dummy image in the fs.
                Mockatoo.when(proc.run(Path.join([ Utils.toolPath(project), Utils.msdfAtlasExecutable() ]), anyIterator)).thenCall(f -> {
                    final args = (cast f[1] : Array<String>);
                    final img  = args[7];
                    final json = args[9];

                    fs.files[img]  = MockFileData.fromBytes(createDummyPng());
                    fs.files[json] = MockFileData.fromText(createDummyJson());

                    return Success(Unit.value);
                });
                Mockatoo.when(proc.run(Path.join([ Utils.toolPath(project), Utils.atlasCreatorExecutable() ]), anyIterator)).thenCall(f -> {
                    final args   = (cast f[1] : Array<String>);
                    final outDir = args[3];
                    final parcel = args[5];
                    final atlas  = createAtlas([
                        { image: '$parcel.png', width: 8, height: 8, packed: [
                            { file: 'custom_font', x:  0, y: 0, width: 8, height: 8 }
                        ] }
                    ]);

                    fs.files.set(Path.join([ outDir, '$parcel.png' ]), MockFileData.fromBytes(createDummyPng()));
                    fs.files.set(Path.join([ outDir, '$parcel.json' ]), MockFileData.fromText(atlas));

                    return Success(Unit.value);
                });

                switch packer.create('assets.json')
                {
                    case Success(data):
                        // Unpack the serialised bytes.
                        final parcel = unpack(data[0].bytes);

                        // Check the image that should have been made from packing the font
                        final resource = (cast parcel.assets.find(r -> r.id == 'parcel.png' && r.type == Image) : ImageResource);
                        resource.width.should.be(8);
                        resource.height.should.be(8);

                        // Check our font
                        final resource = (cast parcel.assets.find(r -> r.id == 'custom_font' && r.type == Font) : FontResource);

                        resource.id.should.be('custom_font');
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(0);
                        resource.y.should.be(0);
                        resource.width.should.be(8);
                        resource.height.should.be(8);
                        resource.u1.should.be(0);
                        resource.v1.should.be(0);
                        resource.u2.should.be(1);
                        resource.v2.should.be(1);
                    case Failure(message):
                        fail(message);
                }
            });
            it('will call atlas-creator tool to combine all images', {
                final assets : JsonDefinition = {
                    assets : {
                        bytes : [],
                        texts : [],
                        fonts : [],
                        images : [
                            { id : 'img1', path : 'img1.png' },
                            { id : 'img2', path : 'img2.png' },
                            { id : 'img3', path : 'img3.png' }
                        ],
                        sheets : [],
                        sprites : [],
                        shaders : []
                    },
                    parcels : [ 
                        { name : 'parcel', depends : [], images : [ 'img1', 'img2', 'img3' ] }
                    ]
                }
                final fs = new MockFileSystem([
                    'assets.json' => MockFileData.fromText(tink.Json.stringify(assets)),
                    'img1.png' => MockFileData.fromBytes(createDummyPng( 4, 6)),
                    'img2.png' => MockFileData.fromBytes(createDummyPng( 8, 3)),
                    'img3.png' => MockFileData.fromBytes(createDummyPng(10, 2))
                ], []);
                final project = project();
                final proc    = mock(Proc);
                final packer  = new Packer(project, fs, proc);

                Mockatoo.when(proc.run(Path.join([ Utils.toolPath(project), Utils.atlasCreatorExecutable() ]), anyIterator)).thenCall(f -> {
                    final args   = (cast f[1] : Array<String>);
                    final outDir = args[3];
                    final parcel = args[5];
                    final atlas  = createAtlas([
                        { image: '$parcel.png', width: 22, height: 6, packed: [
                            { file: 'img1', x:  0, y: 0, width:  4, height: 6 },
                            { file: 'img2', x:  4, y: 0, width:  8, height: 3 },
                            { file: 'img3', x: 12, y: 0, width: 10, height: 2 }
                        ] }
                    ]);

                    fs.files.set(Path.join([ outDir, '$parcel.png' ]), MockFileData.fromBytes(createDummyPng(22, 6)));
                    fs.files.set(Path.join([ outDir, '$parcel.json' ]), MockFileData.fromText(atlas));

                    return Success(Unit.value);
                });

                switch packer.create('assets.json')
                {
                    case Success(data):
                        final parcel = unpack(data[0].bytes);

                        final image = (cast parcel.assets.find(r -> r.id == 'parcel.png' && r.type == Image) : ImageResource);
                        image.width.should.be(22);
                        image.height.should.be(6);

                        final resource = (cast parcel.assets.find(r -> r.id == 'img1' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(0);
                        resource.y.should.be(0);
                        resource.width.should.be(4);
                        resource.height.should.be(6);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        final resource = (cast parcel.assets.find(r -> r.id == 'img2' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(4);
                        resource.y.should.be(0);
                        resource.width.should.be(8);
                        resource.height.should.be(3);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        final resource = (cast parcel.assets.find(r -> r.id == 'img3' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(12);
                        resource.y.should.be(0);
                        resource.width.should.be(10);
                        resource.height.should.be(2);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);
                    case Failure(message):
                        fail(message);
                }
            });
            it('will call aseprite to generate sprite sheets for packing', {
                final assets : JsonDefinition = {
                    assets : {
                        bytes : [],
                        texts : [],
                        fonts : [],
                        images : [],
                        sheets : [],
                        sprites : [
                            { id : 'sprite', path : 'sprites/sprite.aseprite' }
                        ],
                        shaders : []
                    },
                    parcels : [ 
                        { name : 'parcel', depends : [], sprites : [ 'sprite' ] }
                    ]
                }
                final fs = new MockFileSystem([
                    'assets.json' => MockFileData.fromText(tink.Json.stringify(assets)),
                    'sprites/sprite.aseprite' => MockFileData.fromText('')
                ], []);
                final project = project();
                final proc    = mock(Proc);
                final packer  = new Packer(project, fs, proc);

                Mockatoo.when(proc.run('C:/Program Files/Aseprite/aseprite.exe', anyIterator)).thenCall(f -> {
                    final args = (cast f[1] : Array<String>);
                    final png  = args[3];
                    final json = args[5];
                    final spr : JsonSprite = {
                        meta: {
                            app: '', scale: '', size: { w: 64, h: 32 }, format: '', image: '', version: '', frameTags: [
                                { name: 'anim_1', direction: '', from: 0, to: 1 },
                                { name: 'anim_2', direction: '', from: 2, to: 5 }
                            ]
                        },
                        frames: [
                            {
                                filename: '0',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 0, y: 0, w: 32, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            },
                            {
                                filename: '1',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 32, y: 0, w: 32, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            },
                            {
                                filename: '2',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 0, y: 16, w: 16, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            },
                            {
                                filename: '3',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 16, y: 16, w: 16, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            },
                            {
                                filename: '4',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 32, y: 16, w: 16, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            },
                            {
                                filename: '5',
                                duration: 100,
                                trimmed: false,
                                rotated: false,
                                frame: { x: 48, y: 16, w: 16, h: 16 },
                                sourceSize: { w: 0, h: 0 },
                                spriteSourceSize: { x: 0, y: 0, w: 0, h: 0 }
                            }
                        ]
                    }

                    fs.files.set(png, MockFileData.fromText(''));
                    fs.files.set(json, MockFileData.fromText(tink.Json.stringify(spr)));

                    return Success(Unit.value);
                });

                Mockatoo.when(proc.run(Path.join([ Utils.toolPath(project), Utils.atlasCreatorExecutable() ]), anyIterator)).thenCall(f -> {
                    final args   = (cast f[1] : Array<String>);
                    final outDir = args[3];
                    final parcel = args[5];
                    final atlas  = createAtlas([
                        { image: '$parcel.png', width: 64, height: 32, packed: [
                            { file: 'sprite', x: 0, y: 0, width: 64, height: 32 },
                        ] }
                    ]);

                    fs.files.set(Path.join([ outDir, '$parcel.png' ]), MockFileData.fromBytes(createDummyPng(64, 32)));
                    fs.files.set(Path.join([ outDir, '$parcel.json' ]), MockFileData.fromText(atlas));

                    return Success(Unit.value);
                });

                switch packer.create('assets.json')
                {
                    case Success(data):
                        final parcel = unpack(data[0].bytes);

                        final image = (cast parcel.assets.find(r -> r.id == 'parcel.png' && r.type == Image) : ImageResource);
                        image.width.should.be(64);
                        image.height.should.be(32);

                        final resource = (cast parcel.assets.find(r -> r.id == 'sprite' && r.type == Sprite) : SpriteResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(0);
                        resource.y.should.be(0);
                        resource.width.should.be(64);
                        resource.height.should.be(32);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        resource.animations.exists('anim_1').should.be(true);
                        resource.animations.exists('anim_2').should.be(true);

                        resource.animations['anim_1'].length.should.be(2);
                        final frame = resource.animations['anim_1'][0];
                        frame.duration.should.be(100);
                        frame.width.should.be(32);
                        frame.height.should.be(16);
                        frame.u1.should.be(0);
                        frame.v1.should.be(0);
                        frame.u2.should.be(0.5);
                        frame.v2.should.be(0.5);
                        final frame = resource.animations['anim_1'][1];
                        frame.duration.should.be(100);
                        frame.width.should.be(32);
                        frame.height.should.be(16);
                        frame.u1.should.be(0.5);
                        frame.v1.should.be(0);
                        frame.u2.should.be(1);
                        frame.v2.should.be(0.5);

                        resource.animations['anim_2'].length.should.be(4);
                        final frame = resource.animations['anim_2'][0];
                        frame.duration.should.be(100);
                        frame.width.should.be(16);
                        frame.height.should.be(16);
                        frame.u1.should.be(0);
                        frame.v1.should.be(0.5);
                        frame.u2.should.be(0.25);
                        frame.v2.should.be(1);
                        final frame = resource.animations['anim_2'][1];
                        frame.duration.should.be(100);
                        frame.width.should.be(16);
                        frame.height.should.be(16);
                        frame.u1.should.be(0.25);
                        frame.v1.should.be(0.5);
                        frame.u2.should.be(0.5);
                        frame.v2.should.be(1);
                        final frame = resource.animations['anim_2'][2];
                        frame.duration.should.be(100);
                        frame.width.should.be(16);
                        frame.height.should.be(16);
                        frame.u1.should.be(0.5);
                        frame.v1.should.be(0.5);
                        frame.u2.should.be(0.75);
                        frame.v2.should.be(1);
                        final frame = resource.animations['anim_2'][3];
                        frame.duration.should.be(100);
                        frame.width.should.be(16);
                        frame.height.should.be(16);
                        frame.u1.should.be(0.75);
                        frame.v1.should.be(0.5);
                        frame.u2.should.be(1);
                        frame.v2.should.be(1);
                    case Failure(message):
                        fail(message);
                }
            });
            it('will create images frames for pre-computed atlases', {
                final assets : JsonDefinition = {
                    assets : {
                        bytes : [],
                        texts : [],
                        fonts : [],
                        images : [],
                        sheets : [
                            { id : 'atlas', path : 'atlas/sheet.atlas' }
                        ],
                        sprites : [],
                        shaders : []
                    },
                    parcels : [ 
                        { name : 'parcel', depends : [], sheets : [ 'atlas' ] }
                    ]
                }
                final fs = new MockFileSystem([
                    'assets.json' => MockFileData.fromText(tink.Json.stringify(assets)),
                    'atlas/sheet.atlas' => MockFileData.fromText(haxe.Resource.getString('multi_page_atlas')),
                    'atlas/image.png'   => MockFileData.fromBytes(createDummyPng(512, 256)),
                    'atlas/image2.png'  => MockFileData.fromBytes(createDummyPng(512, 256)),
                ], []);
                final project = project();
                final proc    = mock(Proc);
                final packer  = new Packer(project, fs, proc);

                Mockatoo.when(proc.run(Path.join([ Utils.toolPath(project), Utils.atlasCreatorExecutable() ]), anyIterator)).thenCall(f -> {
                    final args   = (cast f[1] : Array<String>);
                    final outDir = args[3];
                    final parcel = args[5];
                    final atlas  = createAtlas([
                        { image: '$parcel.png', width: 1024, height: 256, packed: [
                            { file: 'image', x:   0, y: 0, width: 512, height: 256 },
                            { file: 'image2', x: 512, y: 0, width: 512, height: 256 }
                        ] }
                    ]);

                    fs.files.set(Path.join([ outDir, '$parcel.png' ]), MockFileData.fromBytes(createDummyPng(1024, 256)));
                    fs.files.set(Path.join([ outDir, '$parcel.json' ]), MockFileData.fromText(atlas));

                    return Success(Unit.value);
                });

                switch packer.create('assets.json')
                {
                    case Success(data):
                        final parcel = unpack(data[0].bytes);

                        final image = (cast parcel.assets.find(r -> r.id == 'parcel.png' && r.type == Image) : ImageResource);
                        image.width.should.be(1024);
                        image.height.should.be(256);

                        final resource = (cast parcel.assets.find(r -> r.id == 'section_1' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(4);
                        resource.y.should.be(128);
                        resource.width.should.be(64);
                        resource.height.should.be(96);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        final resource = (cast parcel.assets.find(r -> r.id == 'section_2' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(16);
                        resource.y.should.be(0);
                        resource.width.should.be(48);
                        resource.height.should.be(32);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        final resource = (cast parcel.assets.find(r -> r.id == 'section_3' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(560);
                        resource.y.should.be(95);
                        resource.width.should.be(184);
                        resource.height.should.be(35);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);

                        final resource = (cast parcel.assets.find(r -> r.id == 'section_4' && r.type == ImageFrame) : ImageFrameResource);
                        resource.image.should.be('parcel.png');
                        resource.x.should.be(554);
                        resource.y.should.be(16);
                        resource.width.should.be(45);
                        resource.height.should.be(192);
                        resource.u1.should.beCloseTo(resource.x / image.width);
                        resource.v1.should.beCloseTo(resource.y / image.height);
                        resource.u2.should.beCloseTo((resource.x + resource.width) / image.width);
                        resource.v2.should.beCloseTo((resource.y + resource.height) / image.height);
                    case Failure(message):
                        fail(message);
                }
            });
        });
    }

    function unpack(_bytes : Bytes) : ParcelResource
        return new Serializer().unserialize(Uncompress.run(_bytes), ParcelResource);

    function project() : Project
        return {
            app : {
                name      : "ExecutableName",
                namespace : "com.project.namespace",
                output    : "bin",
                main      : "Main",
                codepaths : [ "src" ],
                backend   : Snow
            },
            parcels : [ 'assets.json' ]
        }

    function createDummyJson() : String
    {
        final data : JsonFontDefinition = {
            atlas   : { width: 8, height: 8, yOrigin: '', size: 0, distanceRange: 0, type: '' },
            metrics : { lineHeight : 0, ascender : 0, descender : 0, underlineY: 0, underlineThickness : 0 },
            kerning : [],
            glyphs  : [
                {
                    unicode: 'a'.code,
                    advance: 0.12,
                    atlasBounds: { left: 0, top: 4, right: 4, bottom: 0 },
                    planeBounds: { left: 0, top: 0.5, right: 0.5, bottom: 0 }
                },
                {
                    unicode: 'A'.code,
                    advance: 0.12,
                    atlasBounds: { left: 4, top: 4, right: 0, bottom: 0 },
                    planeBounds: { left: 0.5, top: 0.5, right: 0, bottom: 0 }
                },
                {
                    unicode: 'b'.code,
                    advance: 0.12,
                    atlasBounds: { left: 0, top: 0, right: 4, bottom: 4 },
                    planeBounds: { left: 0, top: 0, right: 0.5, bottom: 0.5 }
                },
                {
                    unicode: 'B'.code,
                    advance: 0.12,
                    atlasBounds: { left: 4, top: 0, right: 0, bottom: 4 },
                    planeBounds: { left: 0.5, top: 0, right: 0, bottom: 0.5 }
                }
            ]
        }

        return tink.Json.stringify(data);
    }

    function createDummyPng(_width = 8, _height = 8) : Bytes
    {
        final output = new BytesOutput();
        final writer = new format.png.Writer(output);
        final data   = format.png.Tools.build32BGRA(_width, _height, Bytes.alloc(_width * _height * 4));
        
        writer.write(data);

        return output.getBytes();
    }

    function createAtlas(_pages : Array<JsonAtlasPage>) : String
    {
        final data : JsonAtlas = {
            name  : 'parcel',
            pages : _pages
        }

        return tink.Json.stringify(data);
    }
}