package uk.aidanlee.flurry.api.importers.textureatlas;

import haxe.io.Eof;
import haxe.io.StringInput;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.importers.textureatlas.TextureAtlas.TextureAtlasRepeat;
import uk.aidanlee.flurry.api.importers.textureatlas.TextureAtlas.TextureAtlasFilter;
import uk.aidanlee.flurry.api.importers.textureatlas.TextureAtlas.TextureAtlasFormat;
import uk.aidanlee.flurry.api.importers.textureatlas.TextureAtlas.TextureAtlasFrame;

using StringTools;

class TextureAtlasParser
{
    /**
     * Parse a libGDX atlas string.
     * @param _atlasData Atlas data.
     * @return TextureAtlas
     */
    public static function parse(_atlasData : String) : TextureAtlas
    {
        if (_atlasData.length == 0)
        {
            throw 'TextureAtlas Parser : Atlas data string is empty';
        }

        // Filter out empty lines. Atlas files from the libGDX have an empty first line.
        var input   = new StringInput(_atlasData);
        var lines   = [];
        var reading = true;
        while (reading)
        {
            try
            {
                lines.push(input.readLine());
            }
            catch (_e : Eof)
            {
                reading = false;
            }
        }

        lines = lines.filter(f -> f != '');
        
        var name   = lines[0];
        var size   = readSize  (lines[1]);
        var format = readFormat(lines[2]);
        var filter = readFilter(lines[3]);
        var repeat = readRepeat(lines[4]);

        // Cut the meta data lines and read all frames.
        lines.splice(0, 5);
        var frames = readFrames(lines);

        return new TextureAtlas(name, size, format, filter, repeat, frames);
    }

    static function readSize(_line : String) : Vector
    {
        var pos = _line.split(':')[1].split(',');

        return new Vector(Std.parseFloat(pos[0]), Std.parseFloat(pos[1]));
    }

    static function readFormat(_line : String) : TextureAtlasFormat
    {        
        return TextureAtlasFormat.createByName(_line.split(':')[1].trim());
    }

    static function readFilter(_line : String) : Array<TextureAtlasFilter>
    {
        var filters = _line.split(':')[1].split(',');

        return [ TextureAtlasFilter.createByName(filters[0].trim()), TextureAtlasFilter.createByName(filters[1].trim()) ];
    }

    static function readRepeat(_line : String) : TextureAtlasRepeat
    {
        return TextureAtlasRepeat.createByName(_line.split(':')[1].trim());
    }

    /**
     * Reads all the frames from the atlas data.
     * TODO : Make this more generic. Assumes a set frame data order.
     * @param _lines Frame lines.
     * @return Array<TextureAtlasFrame>
     */
    static function readFrames(_lines : Array<String>) : Array<TextureAtlasFrame>
    {
        var frames = new Array<TextureAtlasFrame>();
        var index  = 0;

        while (index < _lines.length)
        {
            var name     = _lines[index];
            var rotated  = readFrameRotated (_lines[index + 1]);
            var region   = readFrameRegion  (_lines[index + 2], _lines[index + 3]);
            var original = readFrameOriginal(_lines[index + 4]);
            var offset   = readFrameOffset  (_lines[index + 5]);
            var frameIdx = readFrameIndex   (_lines[index + 6]);

            frames.push(new TextureAtlasFrame(name, rotated, region, original, offset, frameIdx));
            index += 7;
        }

        return frames;
    }

    static function readFrameRotated(_line : String) : Bool
    {
        return switch(_line.split(':')[1].trim())
        {
            case 'true': true;
            case _: false;
        }
    }

    static function readFrameRegion(_linePos : String, _lineSize : String) : Rectangle
    {
        var pos  = _linePos .split(':')[1].split(',');
        var size = _lineSize.split(':')[1].split(',');

        return new Rectangle(Std.parseFloat(pos[0]), Std.parseFloat(pos[1]), Std.parseFloat(size[0]), Std.parseFloat(size[1]));
    }

    static function readFrameOriginal(_line : String) : Vector
    {
        var original = _line.split(':')[1].split(',');

        return new Vector(Std.parseFloat(original[0]), Std.parseFloat(original[1]));
    }

    static function readFrameOffset(_line : String) : Vector
    {
        var offset = _line.split(':')[1].split(',');

        return new Vector(Std.parseFloat(offset[0]), Std.parseFloat(offset[1]));
    }

    static function readFrameIndex(_line : String) : Int
    {
        return Std.parseInt(_line.split(':')[1].trim());
    }
}
