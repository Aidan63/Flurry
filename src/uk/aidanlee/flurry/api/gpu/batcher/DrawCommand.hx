package uk.aidanlee.flurry.api.gpu.batcher;

import haxe.ds.ReadOnlyArray;
import uk.aidanlee.flurry.api.gpu.PrimitiveType;
import uk.aidanlee.flurry.api.gpu.state.ClipState;
import uk.aidanlee.flurry.api.gpu.state.TargetState;
import uk.aidanlee.flurry.api.gpu.state.DepthState;
import uk.aidanlee.flurry.api.gpu.state.StencilState;
import uk.aidanlee.flurry.api.gpu.state.BlendState;
import uk.aidanlee.flurry.api.gpu.camera.Camera;
import uk.aidanlee.flurry.api.gpu.geometry.Geometry;
import uk.aidanlee.flurry.api.gpu.geometry.UniformBlob;
import uk.aidanlee.flurry.api.gpu.textures.SamplerState;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;

/**
 * A draw command describes how to draw a set amount of data within a vertex buffer.
 * These commands contain the buffer range, shader, texture, viewport, etc.
 */
class DrawCommand
{
    /**
     * All of the geometry in this command.
     */
    public final geometry : ReadOnlyArray<Geometry>;

    /**
     * Projection matrix to draw this command with.
     */
    public final camera : Camera;

    /**
     * Primitive type of this draw command.
     */
    public final primitive : PrimitiveType;

    public final clip : ClipState;

    /**
     * The render target for this draw command.
     */
    public final target : TargetState;

    /**
     * Shader to be used to draw this data.
     */
    public final shader : ShaderResource;

    /**
     * If provided uniform values are fetch from here before the shader defaults.
     */
    public final uniforms : ReadOnlyArray<UniformBlob>;

    /**
     * Textures (if any) to draw with this data.
     */
    public final textures : ReadOnlyArray<ImageResource>;

    public final samplers : ReadOnlyArray<SamplerState>;

    public final depth : DepthState;

    public final stencil : StencilState;

    public final blending : BlendState;

    inline public function new(
        _geometry   : ReadOnlyArray<Geometry>,
        _camera     : Camera,
        _primitive  : PrimitiveType,
        _clip       : ClipState,
        _target     : TargetState,
        _shader     : ShaderResource,
        _uniforms   : ReadOnlyArray<UniformBlob>,
        _textures   : ReadOnlyArray<ImageResource>,
        _samplers   : ReadOnlyArray<SamplerState>,
        _depth      : DepthState,
        _stencil    : StencilState,
        _blending   : BlendState
    )
    {
        geometry   = _geometry;
        camera     = _camera;
        primitive  = _primitive;
        clip       = _clip;
        target     = _target;
        shader     = _shader;
        uniforms   = _uniforms;
        textures   = _textures;
        samplers   = _samplers;
        depth      = _depth;
        stencil    = _stencil;
        blending   = _blending;
    }
}
