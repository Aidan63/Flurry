package uk.aidanlee.flurry.api.resources;

import hxbit.Serializer;
import hxbit.Serializable;
import haxe.io.Bytes;

enum ShaderType
{
    Matrix4;
    Vector4;
}

enum ResourceType
{
    Bytes;
    Text;
    Font;
    Image;
    ImageFrame;
    Sprite;
    Shader;
}

class Resource implements Serializable
{
    @:s public var type (default, null) : ResourceType;

    @:s public var id (default, null) : String;

    public function new(_type : ResourceType, _id : String)
    {
        type = _type;
        id   = _id;
    }
}

class BytesResource extends Resource
{
    @:s public var bytes (default, null) : Bytes;

    public function new(_id : String, _bytes : Bytes)
    {
        super(Bytes, _id);

        bytes = _bytes;
    }
}

class TextResource extends Resource
{
    @:s public var content (default, null) : String;

    public function new(_id : String, _content : String)
    {
        super(Text, _id);

        content = _content;
    }
}

class ImageResource extends Resource
{
    /**
     * Pixel width of this texture.
     */
    @:s public var width (default, null) : Int;

    /**
     * Pixel height of this texture.
     */
    @:s public var height (default, null) : Int;

    /**
     * Pixel data of this texture.
     * Modifying this does not modify the actual images data.
     */
    @:s public var pixels (default, null) : Bytes;

    public function new(_id : String, _width : Int, _height : Int, _pixels : Bytes)
    {
        super(Image, _id);

        width  = _width;
        height = _height;
        pixels = _pixels;
    }
}

class ImageFrameResource extends Resource
{
    /**
     * Unique ID of the `ImageResource` all of the frames are contained within.
     */
    @:s public var image (default, null) : String;

    @:s public var x (default, null) : Int;

    @:s public var y (default, null) : Int;

    @:s public var width (default, null) : Int;

    @:s public var height (default, null) : Int;

    @:s public var u1 (default, null) : Float;

    @:s public var v1 (default, null) : Float;

    @:s public var u2 (default, null) : Float;

    @:s public var v2 (default, null) : Float;

    public function new(_id : String, _image : String, _x : Int, _y : Int, _width : Int, _height : Int, _u1 : Float, _v1 : Float, _u2 : Float, _v2 : Float)
    {
        super(ImageFrame, _id);

        image  = _image;
        x      = _x;
        y      = _y;
        width  = _width;
        height = _height;
        u1     = _u1;
        v1     = _v1;
        u2     = _u2;
        v2     = _v2;
    }
}

class SpriteResource extends ImageFrameResource
{
    @:s public var animations (default, null) : Map<String, Array<SpriteFrameResource>>;

    public function new(_id : String, _image : String, _x : Int, _y : Int, _width : Int, _height : Int, _u1 : Float, _v1 : Float, _u2 : Float, _v2 : Float, _animations : Map<String, Array<SpriteFrameResource>>)
    {
        super(_id, _image, _x, _y, _width, _height, _u1, _v1, _u2, _v2);

        type       = Sprite;
        animations = _animations;
    }
}

class SpriteFrameResource implements Serializable
{
    /**
     * Pixel width of this sprite frame.
     */
    @:s public var width (default, null) : Int;

    /**
     * Pixel height of this sprite frame.
     */
    @:s public var height (default, null) : Int;

    /**
     * Base length in miliseconds this frame will be displayed for.
     */
    @:s public var duration (default, null) : Int;

    @:s public var u1 (default, null) : Float;

    @:s public var v1 (default, null) : Float;

    @:s public var u2 (default, null) : Float;

    @:s public var v2 (default, null) : Float;

    public function new(_width : Int, _height : Int, _duration : Int, _u1 : Float, _v1 : Float, _u2 : Float, _v2 : Float)
    {
        width    = _width;
        height   = _height;
        duration = _duration;
        u1       = _u1;
        v1       = _v1;
        u2       = _u2;
        v2       = _v2;
    }
}

class FontResource extends ImageFrameResource
{
    @:s public var characters (default, null) : Map<Int, Character>;

    @:s public var lineHeight (default, null) : Float;

    public function new(_id : String, _image : String, _characters : Map<Int, Character>, _lineHeight : Float, _x : Int, _y : Int, _width : Int, _height : Int, _u1 : Float, _v1 : Float, _u2 : Float, _v2 : Float)
    {
        super(_id, _image, _x, _y, _width, _height, _u1, _v1, _u2, _v2);

        type       = Font;
        characters = _characters;
        lineHeight = _lineHeight;
    }
}

class Character implements Serializable
{
    @:s public var x (default, null) : Float;

    @:s public var y (default, null) : Float;

    @:s public var width (default, null) : Float;

    @:s public var height (default, null) : Float;

    @:s public var xAdvance (default, null) : Float;

    @:s public var u1 (default, null) : Float;

    @:s public var v1 (default, null) : Float;

    @:s public var u2 (default, null) : Float;

    @:s public var v2 (default, null) : Float;

    public function new(
        _x : Float,
        _y : Float,
        _width : Float,
        _height : Float,
        _xAdvance : Float,
        _u1 : Float,
        _v1 : Float,
        _u2 : Float,
        _v2 : Float)
    {
        x        = _x;
        y        = _y;
        width    = _width;
        height   = _height;
        xAdvance = _xAdvance;
        u1       = _u1;
        v1       = _v1;
        u2       = _u2;
        v2       = _v2;
    }
}

class ShaderResource extends Resource
{
    @:s public var layout (default, null) : ShaderLayout;

    @:s public var ogl3 (default, null) : Null<ShaderSource>;

    @:s public var ogl4 (default, null) : Null<ShaderSource>;

    @:s public var hlsl (default, null) : Null<ShaderSource>;

    public function new(_id : String, _layout : ShaderLayout, _ogl3 : Null<ShaderSource>, _ogl4 : Null<ShaderSource>, _hlsl : Null<ShaderSource>)
    {
        super(Shader, _id);

        layout   = _layout;
        ogl3     = _ogl3;
        ogl4     = _ogl4;
        hlsl     = _hlsl;
    }
}

class ShaderSource implements Serializable
{
    /**
     * If this shader has been compiled offline.
     */
    @:s public var compiled (default, null) : Bool;

    /**
     * Shaders vertex stage data.
     */
    @:s public var vertex (default, null) : Bytes;

    /**
     * Shaders fragment stage data.
     */
    @:s public var fragment (default, null) : Bytes;

    public function new(_compiled : Bool, _vertex : Bytes, _fragment : Bytes)
    {
        compiled = _compiled;
        vertex   = _vertex;
        fragment = _fragment;
    }
}

class ShaderLayout implements Serializable
{
    /**
     * Name of all the textures used in the fragment shader.
     * Names only really matter in Ogl3 shaders, in others the strings location in the array is used as the binding location.
     * So positioning within this array does matter!
     */
    @:s public var textures (default, null) : Array<String>;

    /**
     * All of the UBOs / SSBOs / CBuffers used in this shader.
     */
    @:s public var blocks (default, null) : Array<ShaderBlock>;

    public function new(_textures : Array<String>, _blocks : Array<ShaderBlock>)
    {
        textures = _textures;
        blocks   = _blocks;
    }
}

class ShaderBlock implements Serializable
{
    /**
     * Name of this shader block.
     * A shader block named "defaultMatrices" must have 3 4x4 matrices inside it.
     */
    @:s public var name (default, null) : String;

    /**
     * The location this buffer is bound to.
     * Is not used with the Ogl3 backend.
     */
    @:s public var binding (default, null) : Int;

    /**
     * All of the values in this block.
     */
    @:s public var values (default, null) : Array<ShaderValue>;

    public function new(_name : String, _binding : Int, _values : Array<ShaderValue>)
    {
        name    = _name;
        binding = _binding;
        values  = _values;
    }
}

class ShaderValue implements Serializable
{
    @:s public var name (default, null) : String;

    @:s public var type (default, null) : ShaderType;

    public function new(_name : String, _type : ShaderType)
    {
        name = _name;
        type = _type;
    }
}

class ParcelResource implements Serializable
{
    /**
     * Name of this parcel.
     */
    @:s public var name (default, null) : String;

    /**
     * List of the IDs of all assets to be included in this parcel.
     */
    @:s public var assets (default, null) : Array<Resource>;

    /**
     * List of parcel names this parcel depends on.
     */
    @:s public var depends (default, null) : Array<String>;

    public function new(_name : String, _assets : Array<Resource>, _depends : Array<String>)
    {
        name    = _name;
        assets  = _assets;
        depends = _depends;
    }
}
