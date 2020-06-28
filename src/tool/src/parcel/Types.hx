package parcel;

import uk.aidanlee.flurry.api.resources.Resource.ShaderType;

// Parcel Structures

typedef JsonResource = {
    final id : String;
    final path : String;
}

typedef JsonShaderValue = {
    final type : ShaderType;
    final name : String;
}

typedef JsonShaderBlock = {
    final name : String;
    final binding : Int;
    final values : Array<JsonShaderValue>;
}

typedef JsonShaderDefinition = {
    final textures : Array<String>;
    final blocks : Array<JsonShaderBlock>;
}

typedef JsonShaderSource = {
    final vertex : String;
    final fragment : String;
    final compiled : Bool;
}

typedef JsonShaderResource = JsonResource & {
    final ?ogl3 : JsonShaderSource;
    final ?ogl4 : JsonShaderSource;
    final ?hlsl : JsonShaderSource;
}

typedef JsonParcel = {
    final name : String;
    final depends : Array<String>;
    final ?bytes : Array<String>;
    final ?texts : Array<String>;
    final ?fonts : Array<String>;
    final ?images : Array<String>;
    final ?sheets : Array<String>;
    final ?sprites : Array<String>;
    final ?shaders : Array<String>;
    final ?options : JsonPackingOptions;
}

typedef JsonPackingOptions = {
    final pageMaxWidth : Int;
    final pageMaxHeight : Int;
    final pagePadX : Int;
    final pagePadY : Int;
    final fast : Bool;
    final compressionLevel : Int;
}

typedef JsonAssets = {
    final bytes : Array<JsonResource>;
    final texts : Array<JsonResource>;
    final fonts : Array<JsonResource>;
    final images : Array<JsonResource>;
    final sheets : Array<JsonResource>;
    final sprites : Array<JsonResource>;
    final shaders : Array<JsonShaderResource>;
}

typedef JsonDefinition = {
    final assets : JsonAssets;
    final parcels : Array<JsonParcel>;
}

// Font Structures

typedef JsonFontAtlas = {
    final type : String;
    final distanceRange : Int;
    final size : Int;
    final width : Int;
    final height : Int;
    final yOrigin : String;
}

typedef JsonFontMetrics = {
    final lineHeight : Float;
    final ascender : Float;
    final descender : Float;
    final underlineY : Float;
    final underlineThickness : Float;
}

typedef JsonFontGlyph = {
    final unicode : Int;
    final advance : Float;
    final ?planeBounds : {
        final left : Float;
        final bottom : Float;
        final right : Float;
        final top : Float;
    }
    final ?atlasBounds : {
        final left : Float;
        final bottom : Float;
        final right : Float;
        final top : Float;
    }
}

typedef JsonFontDefinition = {
    final atlas : JsonFontAtlas;
    final metrics : JsonFontMetrics;
    final glyphs : Array<JsonFontGlyph>;
    final kerning : Array<Dynamic>;
}

typedef JsonRectangle = {
    final x : Int;
    final y : Int;
    final w : Int;
    final h : Int;
}

typedef JsonSize = {
    final w : Int;
    final h : Int;
}

// Sprite Structures

typedef JsonSpriteFrame = {
    final filename : String;
    final frame : JsonRectangle;
    final rotated : Bool;
    final trimmed : Bool;
    final spriteSourceSize : JsonRectangle;
    final sourceSize : JsonSize;
    final duration : Int;
}

typedef JsonSpriteTag = {
    final name : String;
    final from : Int;
    final to : Int;
    final direction : String;
}

typedef JsonSpriteMeta = {
    final app : String;
    final version : String;
    final image : String;
    final format : String;
    final size : JsonSize;
    final scale : String;
    final frameTags : Array<JsonSpriteTag>;
}

typedef JsonSprite = {
    final frames : Array<JsonSpriteFrame>;
    final meta : JsonSpriteMeta;
}

// Atlas Structures

typedef JsonAtlas = {
    final name : String;
    final pages : Array<JsonAtlasPage>;
}

typedef JsonAtlasPage = {
    final image : String;
    final width : Int;
    final height : Int;
    final packed : Array<JsonAtlasImage>;
}

typedef JsonAtlasImage = {
    final file : String;
    final x : Int;
    final y : Int;
    final width : Int;
    final height : Int;
}
