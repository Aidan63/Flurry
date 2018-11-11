package uk.aidanlee.flurry.api.gpu.geometry;

import snow.api.Debug.def;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher;
import uk.aidanlee.flurry.api.gpu.geometry.Transformation;
import uk.aidanlee.flurry.api.maths.Hash;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Quaternion;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;

enum PrimitiveType {
    Points;
    Lines;
    LineStrip;
    Triangles;
    TriangleStrip;
}

typedef GeometryOptions = {
    var ?vertices   : Array<Vertex>;
    var ?indices    : Array<Int>;
    var ?transform  : Transformation;
    var ?shader     : ShaderResource;
    var ?textures   : Array<ImageResource>;
    var ?depth      : Int;
    var ?immediate  : Bool;
    var ?unchanging : Bool;
    var ?color      : Color;
    var ?clip       : Rectangle;
    var ?primitive  : PrimitiveType;
    var ?batchers   : Array<Batcher>;
    var ?blend      : Blending;
}

/**
 * The geometry class is the primary way of displaying visuals to the screen.
 * 
 * Geometry contains a collection of vertices which defines the shape of the geometry
 * and other rendering properties which will decide how it is drawn to the screen.
 */
class Geometry
{
    /**
     * Randomly generated ID for this geometry.
     */
    public final id : Int;

    /**
     * All of the batchers this geometry is in.
     */
    public final batchers : Array<Batcher>;

    /**
     * Transformation of this geometry.
     */
    public final transformation : Transformation;

    /**
     * Vertex data of this geometry.
     */
    public final vertices : Array<Vertex>;

    /**
     * Index data of this geometry.
     * If it is empty then the geometry is drawn unindexed.
     */
    public final indices : Array<Int>;

    /**
     * Default colour of this geometry.
     */
    public final color : Color;

    /**
     * The blend state for this geometry.
     */
    public final blend : Blending;

    /**
     * Clipping rectangle for this geometry. Null if none.
     */
    public final clip : Rectangle;

    /**
     * All of the images this image will provide to the shader.
     */
    public final textures : Array<ImageResource>;

    /**
     * The specific shader for the geometry.
     * If null the batchers shader is used.
     */
    public var shader (default, set) : ShaderResource;

    inline function set_shader(_shader : ShaderResource) : ShaderResource {
        dirtyBatchers();

        return shader = _shader;
    }

    /**
     * The depth of this mesh within the batcher.
     */
    public var depth (default, set) : Float;

    inline function set_depth(_depth : Float) : Float {
        dirtyBatchers();

        return depth = _depth;
    }

    /**
     * The primitive type of this geometry.
     */
    public var primitive (default, set) : PrimitiveType;

    inline function set_primitive(_primitive : PrimitiveType) : PrimitiveType {
        dirtyBatchers();

        return primitive = _primitive;
    }

    /**
     * Unchanging geometry is drawn once and them immediately dropped.
     */
    public var immediate : Bool;

    /**
     * If geometry is set to unchanging then its vertex data will only be uploaded once.
     * Any further changes to the vertices will not be reflected on the GPU until unchanging is disabled.
     * 
     * This is an optimisation hint to the rendering backends, although not all backends will optimise
     * unchaning geometry.
     */
    public var unchanging : Bool;

    /**
     * The position of the geometry.
     */
    public var position (get, never) : Vector;

    inline function get_position() : Vector {
        return transformation.position;
    }

    /**
     * The origin of the geometry.
     */
    public var origin (get, never) : Vector;

    inline function get_origin() : Vector {
        return transformation.origin;
    }

    /**
     * Rotation of the geometry.
     */
    public var rotation (get, never) : Quaternion;

    inline function get_rotation() : Quaternion {
        return transformation.rotation;
    }

    /**
     * Scale of the geometry.
     */
    public var scale (get, never) : Vector;

    inline function get_scale() : Vector {
        return transformation.scale;
    }

    /**
     * Create a new mesh, contains no vertices and no transformation.
     */
    public function new(_options : GeometryOptions)
    {
        id = Hash.uniqueHash();

        batchers       = [];
        vertices       = def(_options.vertices  , []);
        indices        = def(_options.indices   , []);
        transformation = def(_options.transform , inline new Transformation());
        clip           = def(_options.clip      , inline new Rectangle());
        textures       = def(_options.textures  , []);
        depth          = def(_options.depth     , 0);
        unchanging     = def(_options.unchanging, false);
        immediate      = def(_options.immediate , false);
        primitive      = def(_options.primitive , Triangles);
        color          = def(_options.color     , inline new Color());
        blend          = def(_options.blend     , inline new Blending());
        shader         = _options.shader;

        // Add to batchers.
        for (batcher in def(_options.batchers  , []))
        {
            batcher.addGeometry(this);
        }
    }

    /**
     * Add a vertex to this mesh.
     * @param _v Vertex to add.
     */
    public function addVertex(_v : Vertex)
    {
        vertices.push(_v);
    }

    /**
     * Remove a vertex from this mesh.
     * @param _v Vertex to remove.
     */
    public function removeVertex(_v : Vertex)
    {
        vertices.remove(_v);
    }

    /**
     * Add a texture to this geometry.
     * Batchers are automatically dirtied.
     * @param _image Image to add.
     */
    public function addTexture(_image : ImageResource)
    {
        textures.push(_image);
        dirtyBatchers();
    }

    /**
     * Remove a texture from this geometry.
     * Batchers are automatically dirtied.
     * @param _image Image to remove.
     */
    public function removeTexture(_image : ImageResource)
    {
        textures.remove(_image);
        dirtyBatchers();
    }

    /**
     * Replace a texture in this geometry.
     * Batchers are automatically dirtied.
     * @param _idx   Texture ID to replace.
     * @param _image Texture to replace with.
     */
    public function setTexture(_idx : Int, _image : ImageResource)
    {
        textures[_idx] = _image;
        dirtyBatchers();
    }

    /**
     * Remove this geometry from all the batchers it is in.
     */
    public function drop()
    {
        for (batcher in batchers)
        {
            batcher.removeGeometry(this);
        }

        batchers.resize(0);
    }

    /**
     * Flags all the batchers this geometry is in for re-ordering.
     */
    public function dirtyBatchers()
    {
        for (batcher in batchers)
        {
            batcher.setDirty();
        }
    }

    /**
     * Convenience function to check if this geometry is indexed.
     */
    public function isIndexed()
    {
        return indices.length != 0;
    }
}
