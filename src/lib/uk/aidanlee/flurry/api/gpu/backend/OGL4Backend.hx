package uk.aidanlee.flurry.api.gpu.backend;

import uk.aidanlee.flurry.api.resources.Resource.ResourceID;
import uk.aidanlee.flurry.api.resources.Resource.ImageFrameResource;
import haxe.Exception;
import haxe.io.Bytes;
import haxe.ds.ReadOnlyArray;
import cpp.RawConstPointer;
import cpp.ConstCharStar;
import cpp.UInt8;
import cpp.Pointer;
import sdl.GLContext;
import sdl.Window;
import sdl.SDL;
import glad.Glad;
import opengl.GL.*;
import opengl.GL.GLSync;
import opengl.WebGL;
import rx.disposables.ISubscription;
import uk.aidanlee.flurry.FlurryConfig.FlurryWindowConfig;
import uk.aidanlee.flurry.FlurryConfig.FlurryRendererOgl4Config;
import uk.aidanlee.flurry.api.maths.Maths;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.display.DisplayEvents;
import uk.aidanlee.flurry.api.buffers.Float32BufferData;
import uk.aidanlee.flurry.api.resources.Resource.Resource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderLayout;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderBlock;
import uk.aidanlee.flurry.api.resources.ResourceEvents;
import uk.aidanlee.flurry.api.gpu.state.BlendState;
import uk.aidanlee.flurry.api.gpu.state.StencilState;
import uk.aidanlee.flurry.api.gpu.state.DepthState;
import uk.aidanlee.flurry.api.gpu.state.TargetState;
import uk.aidanlee.flurry.api.gpu.batcher.DrawCommand;
import uk.aidanlee.flurry.api.gpu.textures.SamplerState;
import cpp.Stdlib.memcpy;

using rx.Observable;
using cpp.NativeArray;
using uk.aidanlee.flurry.api.gpu.backend.OGLUtils;

class OGL4Backend implements IRendererBackend
{
    static final BUFFERING_COUNT = 3;

    /**
     * The number of floats in each vertex.
     */
    static final VERTEX_BYTE_SIZE = 36;

    /**
     * The byte offset for the position in each vertex.
     */
    static final VERTEX_OFFSET_POS = 0;

    /**
     * The byte offset for the colour in each vertex.
     */
    static final VERTEX_OFFSET_COL = 3;

    /**
     * The byte offset for the texture coordinates in each vertex.
     */
    static final VERTEX_OFFSET_TEX = 7;

    /**
     * Signals for when shaders and images are created and removed.
     */
    final resourceEvents : ResourceEvents;

    /**
     * Signals for when a window change has been requested and dispatching back the result.
     */
    final displayEvents : DisplayEvents;

    /**
     * The single VAO which is bound once when the backend is created.
     */
    final glVao : Int;

    /**
     * The single VBO used by the backend.
     */
    final glVertexBuffer : Int;

    /**
     * The single index buffer used by the backend.
     */
    final glIndexbuffer : Int;

    /**
     * The ubo used to store all matrix data.
     */
    final glMatrixBuffer : Int;

    final glIndirectBuffer : Int;

    /**
     * The ubo used to store all uniform data.
     */
    final glUniformBuffer : Int;

    final vertexBuffer : Pointer<UInt8>;

    final indexBuffer : Pointer<UInt8>;

    final matrixBuffer : Pointer<UInt8>;

    final uniformBuffer : Pointer<UInt8>;

    final indirectBuffer : Pointer<UInt8>;

    final vertexRangeSize : Int;

    final indexRangeSize : Int;

    final matrixRangeSize : Int;

    final uniformRangeSize : Int;

    final indirectRangeSize : Int;

    final multiDrawIndexedCopyBuffer : Bytes;

    final multiDrawUnIndexedCopyBuffer : Bytes;

    /**
     * Shader programs keyed by their associated shader resource IDs.
     */
    final shaderPrograms : Map<Int, Int>;

    /**
     * Shader uniform locations keyed by their associated shader resource IDs.
     */
    final shaderUniforms : Map<Int, ShaderInformation>;

    /**
     * Texture objects keyed by their associated image resource IDs.
     */
    final textureObjects : Map<Int, Int>;

    /**
     * Keep track of all our texture sizes.
     * After they are created draw calls refer to their IDs so we manually store the dimensions.
     */
    final textureInfo : Map<Int, TextureInformation>;

    /**
     * The sampler objects which have been created for each specific texture.
     */
    final samplerObjects : Map<Int, Map<Int, Int>>;

    /**
     * Framebuffer objects keyed by their associated image resource IDs.
     * Framebuffers will only be generated when an image resource is used as a target.
     * Will be destroyed when the associated image resource is destroyed.
     */
    final framebufferObjects : Map<Int, Int>;

    /**
     * The default sampler object to use if none is specified.
     */
    final defaultSampler : Int;

    /**
     * OpenGL sync objects used to lock writing into buffer ranges until they are visible to the GPU.
     */
    final rangeSyncPrimitives : Array<GLSyncWrapper>;

    /**
     * Array of opengl textures objects which will be bound.
     * Size of this array is equal to the max number of texture bindings allowed.
     */
    final textureSlots : Array<Int>;

    /**
     * Array of opengl sampler objects which will be bound.
     * Size of this array is equal to the max number of texture bindings allowed.
     */
    final samplerSlots : Array<Int>;

    /**
     * All the commands queued for uploading and drawing.
     */
    final commandQueue : Array<DrawCommand>;

    /**
     * The bytes alignment for ubos.
     */
    final glUboAlignment : Int;

    final resourceCreatedSubscription : ISubscription;

    final resourceRemovedSubscription : ISubscription;

    final displaySizeChangedSubscription : ISubscription;

    final displayChangeRequestSubscription : ISubscription;

    /**
     * Backbuffer display, default target if none is specified.
     */
    var backbuffer : BackBuffer;

    /**
     * The index of the current buffer range which is being written into this frame.
     */
    var currentRange : Int;

    // GL state variables

    var target     : TargetState;
    var shader     : ResourceID;
    final clip     : Rectangle;
    final viewport : Rectangle;
    final blend    : BlendState;
    final depth    : DepthState;
    final stencil  : StencilState;
    var ssbo : Int;
    var cmds : Int;

    // SDL Window and GL Context

    var window : Window;

    var glContext : GLContext;

    /**
     * Creates a new openGL 4.5 renderer.
     * @param _renderer           Access to the renderer which owns this backend.
     * @param _dynamicVertices    The maximum number of dynamic vertices in the buffer.
     * @param _unchangingVertices The maximum number of static vertices in the buffer.
     */
    public function new(_resourceEvents : ResourceEvents, _displayEvents : DisplayEvents, _windowConfig : FlurryWindowConfig, _rendererConfig : FlurryRendererOgl4Config)
    {
        createWindow(_windowConfig);

        resourceEvents = _resourceEvents;
        displayEvents  = _displayEvents;

        // Create two empty buffers, for the vertex and index data
        var buffers = [ 0, 0, 0, 0, 0 ];
        glCreateBuffers(buffers.length, buffers);
        glVertexBuffer   = buffers[0];
        glIndexbuffer    = buffers[1];
        glMatrixBuffer   = buffers[2];
        glUniformBuffer  = buffers[3];
        glIndirectBuffer = buffers[4];

        var uboAlignment = [ 0 ];
        glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, uboAlignment);

        glUboAlignment = uboAlignment[0];

        vertexRangeSize   = _rendererConfig.vertexBufferSize;
        indexRangeSize    = _rendererConfig.indexBufferSize;
        uniformRangeSize  = _rendererConfig.uniformBufferSize;
        indirectRangeSize = _rendererConfig.indirectBufferSize;
        matrixRangeSize   = Maths.nextMultipleOff(_rendererConfig.matrixBufferSize, glUboAlignment);

        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", glVertexBuffer  , BUFFERING_COUNT * vertexRangeSize  , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", glIndexbuffer   , BUFFERING_COUNT * indexRangeSize   , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", glMatrixBuffer  , BUFFERING_COUNT * matrixRangeSize  , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", glUniformBuffer , BUFFERING_COUNT * uniformRangeSize , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", glIndirectBuffer, BUFFERING_COUNT * indirectRangeSize, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);

        multiDrawIndexedCopyBuffer   = Bytes.alloc(20);
        multiDrawUnIndexedCopyBuffer = Bytes.alloc(16);

        // Create the vao and bind the vbo to it.
        var vao = [ 0 ];
        glCreateVertexArrays(vao.length, vao);
        glVao = vao[0];

        glVertexArrayVertexBuffer(glVao, 0, glVertexBuffer, 0, VERTEX_BYTE_SIZE);

        // Enable and setup the vertex attributes for this batcher.
        glVertexArrayAttribFormat(glVertexBuffer, 0, 3, GL_FLOAT, false, Float32BufferData.BYTES_PER_FLOAT * VERTEX_OFFSET_POS);
        glVertexArrayAttribFormat(glVertexBuffer, 1, 4, GL_FLOAT, false, Float32BufferData.BYTES_PER_FLOAT * VERTEX_OFFSET_COL);
        glVertexArrayAttribFormat(glVertexBuffer, 2, 2, GL_FLOAT, false, Float32BufferData.BYTES_PER_FLOAT * VERTEX_OFFSET_TEX);

        glEnableVertexArrayAttrib(glVao, 0);
        glEnableVertexArrayAttrib(glVao, 1);
        glEnableVertexArrayAttrib(glVao, 2);

        glVertexArrayAttribBinding(glVao, 0, 0);
        glVertexArrayAttribBinding(glVao, 1, 0);
        glVertexArrayAttribBinding(glVao, 2, 0);

        // Bind our VAO once.
        glBindVertexArray(glVao);

        // Setup single time binds
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, glIndexbuffer);
        glBindBuffer(GL_DRAW_INDIRECT_BUFFER, glIndirectBuffer);

        var samplers = [ 0 ];
        glCreateSamplers(samplers.length, samplers);
        defaultSampler = samplers[0];
        glSamplerParameteri(defaultSampler, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glSamplerParameteri(defaultSampler, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glSamplerParameteri(defaultSampler, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glSamplerParameteri(defaultSampler, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        // Map the streaming parts of the vertex and index buffer.
        vertexBuffer   = Pointer.fromRaw(glMapNamedBufferRange(glVertexBuffer  , 0, BUFFERING_COUNT * vertexRangeSize  , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();
        indexBuffer    = Pointer.fromRaw(glMapNamedBufferRange(glIndexbuffer   , 0, BUFFERING_COUNT * indexRangeSize   , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();
        matrixBuffer   = Pointer.fromRaw(glMapNamedBufferRange(glMatrixBuffer  , 0, BUFFERING_COUNT * matrixRangeSize  , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();
        uniformBuffer  = Pointer.fromRaw(glMapNamedBufferRange(glUniformBuffer , 0, BUFFERING_COUNT * uniformRangeSize , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();
        indirectBuffer = Pointer.fromRaw(glMapNamedBufferRange(glIndirectBuffer, 0, BUFFERING_COUNT * indirectRangeSize, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();

        rangeSyncPrimitives    = [ for (_ in 0...BUFFERING_COUNT) new GLSyncWrapper() ];
        currentRange           = 0;
        commandQueue           = [];

        backbuffer = createBackbuffer(_windowConfig.width, _windowConfig.height, false);

        // Default blend mode
        // Blend equation is not currently changable
        glEnable(GL_BLEND);
        glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO);

        // Set the clear colour
        glClearColor(_rendererConfig.clearColour.x, _rendererConfig.clearColour.y, _rendererConfig.clearColour.z, _rendererConfig.clearColour.w);

        // Default scissor test
        glEnable(GL_SCISSOR_TEST);
        glScissor(0, 0, backbuffer.width, backbuffer.height);

        glClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);

        // default state
        viewport     = new Rectangle();
        clip         = new Rectangle();
        blend        = new BlendState();
        depth        = {
            depthTesting  : false,
            depthMasking  : false,
            depthFunction : Always
        };
        stencil      = {
            stencilTesting : false,

            stencilFrontMask          : 0xff,
            stencilFrontFunction      : Always,
            stencilFrontTestFail      : Keep,
            stencilFrontDepthTestFail : Keep,
            stencilFrontDepthTestPass : Keep,
            
            stencilBackMask          : 0xff,
            stencilBackFunction      : Always,
            stencilBackTestFail      : Keep,
            stencilBackDepthTestFail : Keep,
            stencilBackDepthTestPass : Keep
        };
        shader = 0;
        target = Backbuffer;
        ssbo   = 0;
        cmds   = 0;

        textureSlots       = [ for (_ in 0...GL_MAX_TEXTURE_IMAGE_UNITS) 0 ];
        samplerSlots       = [ for (_ in 0...GL_MAX_TEXTURE_IMAGE_UNITS) 0 ];
        shaderPrograms     = [];
        shaderUniforms     = [];
        textureObjects     = [];
        textureInfo        = [];
        samplerObjects     = [];
        framebufferObjects = [];

        resourceCreatedSubscription = resourceEvents.created.subscribeFunction(onResourceCreated);
        resourceRemovedSubscription = resourceEvents.removed.subscribeFunction(onResourceRemoved);

        displaySizeChangedSubscription   = displayEvents.sizeChanged.subscribeFunction(onSizeChanged);
        displayChangeRequestSubscription = displayEvents.changeRequested.subscribeFunction(onChangeRequest);
    }

    @:void static function glDebugCallback(_source : cpp.UInt32, _type : cpp.UInt32, _id : cpp.UInt32, _severity : cpp.UInt32, _length : Int, _message : cpp.ConstCharStar, _userParam : cpp.RawConstPointer<cpp.Void>)
    {
        Sys.println('OpenGL Debug Callback');
        Sys.println('\tid       : $_id');
        Sys.println('\tmessage  : $_message');
        Sys.println('\tsource   : ${ switch _source {
                case GL_DEBUG_SOURCE_API: 'api';
                case GL_DEBUG_SOURCE_APPLICATION: 'application';
                case GL_DEBUG_SOURCE_OTHER: 'other';
                case GL_DEBUG_SOURCE_SHADER_COMPILER: 'shader compiler';
                case GL_DEBUG_SOURCE_THIRD_PARTY: 'third party';
                case GL_DEBUG_SOURCE_WINDOW_SYSTEM: 'window system';
                case _unknown: 'unknown source : $_unknown';
        } }');
        Sys.println('\ttype     : ${ switch _type {
                case GL_DEBUG_TYPE_ERROR: 'error';
                case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: 'deprecated behaviour';
                case GL_DEBUG_TYPE_MARKER: 'marker';
                case GL_DEBUG_TYPE_OTHER: 'other';
                case GL_DEBUG_TYPE_PERFORMANCE: 'performance';
                case GL_DEBUG_TYPE_POP_GROUP: 'pop group';
                case GL_DEBUG_TYPE_PORTABILITY: 'portability';
                case GL_DEBUG_TYPE_PUSH_GROUP: 'push group';
                case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR: 'undefined behaviour';
                case _unknown: 'unknown type : $_unknown';
            } }');
        Sys.println('\tseverity : ${ switch _severity {
                case GL_DEBUG_SEVERITY_HIGH: 'high';
                case GL_DEBUG_SEVERITY_LOW: 'low';
                case GL_DEBUG_SEVERITY_MEDIUM: 'medium';
                case GL_DEBUG_SEVERITY_NOTIFICATION: 'notification';
                case _unknown: 'unknown severity : $_unknown';
            } }');
    }

    /**
     * Queue a command to be drawn this frame.
     * @param _command Command to draw.
     */
    public function queue(_command : DrawCommand)
    {
        commandQueue.push(_command);
    }

    /**
     * Uploads all data to the gpu then issues draw calls for all queued commands.
     */
    public function submit()
    {
        // waits until the range we will write to is ready and clears the backbuffer.
        if (rangeSyncPrimitives[currentRange].sync != null)
        {
            while (true)
            {
                var waitReturn = glClientWaitSync(rangeSyncPrimitives[currentRange].sync, GL_SYNC_FLUSH_COMMANDS_BIT, 1000);
                if (waitReturn == GL_ALREADY_SIGNALED || waitReturn == GL_CONDITION_SATISFIED)
                {
                    break;
                }
                else
                {
                    throw new OGL4FailedToWaitForSyncObject(waitReturn);
                }
            }
        }
        glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // Upload and draw all commands
        uploadData();
        drawCommands();

        // Once all commands have been drawn we blit and vertically flip our custom backbuffer into the windows backbuffer.
        // A new fence sync is setup for the commands just submitted.
        // We then call the SDL function to swap the window.
        updateClip(0, 0, backbuffer.width, backbuffer.height);
        glBlitNamedFramebuffer(
            backbuffer.framebuffer, 0,
            0, 0, backbuffer.width, backbuffer.height,
            0, backbuffer.height, backbuffer.width, 0,
            GL_COLOR_BUFFER_BIT, GL_NEAREST);

        glDeleteSync(rangeSyncPrimitives[currentRange].sync);
        rangeSyncPrimitives[currentRange].sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        SDL.GL_SwapWindow(window);

        currentRange = (currentRange + 1) % BUFFERING_COUNT;
        commandQueue.resize(0);
    }

    /**
     * Unmap the buffer and iterate over all resources deleting their resources and remove them from the structure.
     */
    public function cleanup()
    {
        resourceCreatedSubscription.unsubscribe();
        resourceRemovedSubscription.unsubscribe();
        
        displaySizeChangedSubscription.unsubscribe();
        displayChangeRequestSubscription.unsubscribe();

        for (_ => shader in shaderPrograms)
        {
            glDeleteProgram(shader);
        }

        for (_ => texture in textureObjects)
        {
            glDeleteTextures(1, [ texture ]);
        }

        for (_ => samplers in samplerObjects)
        {
            for (_ => sampler in samplers)
            {
                glDeleteSamplers(1, [ sampler ]);
            }
        }

        for (_ => framebuffer in framebufferObjects)
        {
            glDeleteFramebuffers(1, [ framebuffer ]);
        }

        glDeleteFramebuffers(1, [ backbuffer.framebuffer ]);

        shaderPrograms.clear();
        shaderUniforms.clear();
        textureObjects.clear();
        samplerObjects.clear();
        framebufferObjects.clear();

        SDL.GL_DeleteContext(glContext);
        SDL.destroyWindow(window);
    }

    /**
     * Writes all vertex, matrix, uniform, and command data into the mapped buffers.
     * The projection and view matrix only need to be added once for an entire command due to multi draw indirect.
     */
    function uploadData()
    {
        var vtxUploaded = currentRange * vertexRangeSize;
        var idxUploaded = currentRange * indexRangeSize;
        var matUploaded = currentRange * matrixRangeSize;
        var unfUploaded = currentRange * uniformRangeSize;
        var cmdUploaded = currentRange * indirectRangeSize;

        for (command in commandQueue)
        {
            final proj : Float32BufferData = command.camera.projection;
            final view : Float32BufferData = command.camera.view;

            memcpy(matrixBuffer.add(matUploaded)     , proj.bytes.getData().address(proj.byteOffset), 64);
            memcpy(matrixBuffer.add(matUploaded + 64), view.bytes.getData().address(view.byteOffset), 64);

            matUploaded += 128;

            // Upload the uniform data
            for (block in command.uniforms)
            {
                memcpy(
                    uniformBuffer.add(unfUploaded),
                    block.buffer.bytes.getData().address(block.buffer.byteOffset),
                    block.buffer.byteLength);
                
                unfUploaded = Maths.nextMultipleOff(unfUploaded + block.buffer.byteLength, glUboAlignment);
            }

            for (geometry in command.geometry)
            {
                switch geometry.data
                {
                    case Indexed(_vertices, _indices):
                        // Memcpy vertex blob data
                        memcpy(
                            indexBuffer.add(idxUploaded),
                            _indices.buffer.bytes.getData().address(_indices.buffer.byteOffset),
                            _indices.buffer.byteLength);
                        memcpy(
                            vertexBuffer.add(vtxUploaded),
                            _vertices.buffer.bytes.getData().address(_vertices.buffer.byteOffset),
                            _vertices.buffer.byteLength);

                        // Upload command data
                        multiDrawIndexedCopyBuffer.setInt32( 0, cast _indices.buffer.byteLength / 2); // Number of indices
                        multiDrawIndexedCopyBuffer.setInt32( 4, 1); // number of instances (always 1)
                        multiDrawIndexedCopyBuffer.setInt32( 8, cast idxUploaded / 2); // number of indices into the buffer
                        multiDrawIndexedCopyBuffer.setInt32(12, cast vtxUploaded / VERTEX_BYTE_SIZE); // number of vertices into the buffer
                        multiDrawIndexedCopyBuffer.setInt32(16, 0); // base instance (always 0)
                        memcpy(
                            indirectBuffer.add(cmdUploaded),
                            multiDrawIndexedCopyBuffer.getData().address(0),
                            multiDrawIndexedCopyBuffer.length);

                        // Increase all offsets
                        vtxUploaded += _vertices.buffer.byteLength;
                        idxUploaded += _indices.buffer.byteLength;
                        cmdUploaded += multiDrawIndexedCopyBuffer.length;
                        
                    case UnIndexed(_vertices):
                        // Memcpy vertex blob data
                        memcpy(
                            vertexBuffer.add(vtxUploaded),
                            _vertices.buffer.bytes.getData().address(_vertices.buffer.byteOffset),
                            _vertices.buffer.byteLength);

                        // Upload command data
                        multiDrawUnIndexedCopyBuffer.setInt32( 0, cast _vertices.buffer.byteLength / VERTEX_BYTE_SIZE); // Number of vertices
                        multiDrawUnIndexedCopyBuffer.setInt32( 4, 1); // number of instances (always 1)
                        multiDrawUnIndexedCopyBuffer.setInt32( 8, cast vtxUploaded / VERTEX_BYTE_SIZE); // number of vertices into the buffer
                        multiDrawUnIndexedCopyBuffer.setInt32(12, 0); // base instance (always 0)
                        memcpy(
                            indirectBuffer.add(cmdUploaded),
                            multiDrawUnIndexedCopyBuffer.getData().address(0),
                            multiDrawUnIndexedCopyBuffer.length);

                        vtxUploaded += _vertices.buffer.byteLength;
                        cmdUploaded += multiDrawUnIndexedCopyBuffer.length;
                }

                // Upload the model matrix
                final model : Float32BufferData = geometry.transformation.world.matrix;
                memcpy(matrixBuffer.add(matUploaded), model.bytes.getData().address(model.byteOffset), 64);

                matUploaded += 64;
            }

            matUploaded = Maths.nextMultipleOff(matUploaded, glUboAlignment);
        }
    }

    /**
     * Loop over all commands and issue draw calls for them.
     */
    function drawCommands()
    {
        var matOffset = currentRange * matrixRangeSize;
        var unfOffset = currentRange * uniformRangeSize;
        var cmdOffset = currentRange * indirectRangeSize;

        for (command in commandQueue)
        {
            updateState(command);

            // Bind the correct range for the matrix buffer
            final info = shaderUniforms[command.shader];

            glBindBufferRange(
                GL_SHADER_STORAGE_BUFFER,
                findBlockIndexByName("flurry_matrices",
                info.layout.blocks),
                glMatrixBuffer,
                matOffset, 128 + (64 * command.geometry.length));

            // Bind the correct range for all uniforms
            for (block in command.uniforms)
            {
                final info = shaderUniforms[command.shader];

                glBindBufferRange(
                    GL_SHADER_STORAGE_BUFFER,
                    findBlockIndexByName(block.name, info.layout.blocks),
                    glUniformBuffer,
                    unfOffset,
                    block.buffer.byteLength);
    
                unfOffset = Maths.nextMultipleOff(unfOffset + block.buffer.byteLength, glUboAlignment);
            }

            // Would like a nicer way to get if the command is indexed or unindexed
            // Problem is that OGl4 doesn't manually issue draw commands for all geometries
            switch command.geometry[0].data
            {
                case Indexed(_, _):
                    untyped __cpp__('glMultiDrawElementsIndirect({0}, GL_UNSIGNED_SHORT, (const void *){1}, {2}, 0)',
                        command.primitive.getPrimitiveType(),
                        cmdOffset,
                        command.geometry.length);

                    cmdOffset += (multiDrawIndexedCopyBuffer.length * command.geometry.length);
                case UnIndexed(_):
                    untyped __cpp__('glMultiDrawArraysIndirect({0}, (const void *){1}, {2}, 0)',
                        command.primitive.getPrimitiveType(),
                        cmdOffset,
                        command.geometry.length);
                    
                    cmdOffset += (multiDrawUnIndexedCopyBuffer.length * command.geometry.length);
            }

            matOffset += 128 + (64 * command.geometry.length);
            matOffset = Maths.nextMultipleOff(matOffset, glUboAlignment);
        }
    }

    // #region SDL Window Management

    function createWindow(_options : FlurryWindowConfig)
    {        
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, 0x0001); // Debug context

        window    = SDL.createWindow(_options.title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, _options.width, _options.height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
        glContext = SDL.GL_CreateContext(window);

        SDL.GL_MakeCurrent(window, glContext);

        if (Glad.gladLoadGLLoader(untyped __cpp__('&SDL_GL_GetProcAddress')) == 0)
        {
            throw new OGL4FailedToLoad();
        }

        final flags = [ 0 ];
        glGetIntegerv(GL_CONTEXT_FLAGS, flags);
        if (cast flags[0] & GL_CONTEXT_FLAG_DEBUG_BIT)
        {
            glEnable(GL_DEBUG_OUTPUT);
            glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
            untyped __cpp__('glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nullptr, GL_TRUE)');
            untyped __cpp__('glDebugMessageCallback({0}, nullptr)', cpp.Callable.fromStaticFunction(glDebugCallback));
        }
    }

    function onChangeRequest(_event : DisplayEventChangeRequest)
    {
        SDL.setWindowSize(window, _event.width, _event.height);
        SDL.setWindowFullscreen(window, _event.fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
        SDL.GL_SetSwapInterval(_event.vsync ? 1 : 0);
    }

    function onSizeChanged(_event : DisplayEventData)
    {
        backbuffer = createBackbuffer(_event.width, _event.height);
    }

    // #endregion

    // #region Resource Management

    function onResourceCreated(_resource : Resource)
    {
        switch _resource.type
        {
            case Image  : createTexture(cast _resource);
            case Shader : createShader(cast _resource);
            case _:
        }
    }

    function onResourceRemoved(_resource : Resource)
    {
        switch _resource.type
        {
            case Image  : removeTexture(_resource.id);
            case Shader : removeShader(_resource.id);
            case _:
        }
    }

    /**
     * Create a shader from a resource.
     * @param _resource Resource to create a shader of.
     */
    function createShader(_resource : ShaderResource)
    {
        if (shaderPrograms.exists(_resource.id))
        {
            return;
        }

        if (_resource.ogl4 == null)
        {
            throw new OGL4NoShaderSourceException(_resource.name);
        }

        var vertex   = 0;
        var fragment = 0;
        if (_resource.ogl4.compiled)
        {
            vertex   = vertexFromSPIRV(_resource.ogl4.vertex);
            fragment = fragmentFromSPIRV(_resource.ogl4.fragment);
        }
        else
        {
            vertex   = vertexFromSource(_resource.ogl4.vertex.toString());
            fragment = fragmentFromSource(_resource.ogl4.fragment.toString());
        }

        // Link the shaders into a program.
        final program = glCreateProgram();
        glAttachShader(program, vertex);
        glAttachShader(program, fragment);
        glLinkProgram(program);

        if (WebGL.getProgramParameter(program, GL_LINK_STATUS) == 0)
        {
            throw new OGL4ShaderLinkingException(_resource.name, WebGL.getProgramInfoLog(program));
        }

        // Delete the shaders now that they're linked
        glDeleteShader(vertex);
        glDeleteShader(fragment);

        final textureLocations = [ for (t in _resource.layout.textures) glGetUniformLocation(program, t) ];
        final blockBindings    = [ for (i in 0..._resource.layout.blocks.length) _resource.layout.blocks[i].binding ];

        shaderPrograms.set(_resource.id, program);
        shaderUniforms.set(_resource.id, new ShaderInformation(_resource.layout, textureLocations, blockBindings));
    }

    function vertexFromSPIRV(_spirv : Bytes) : Int
    {
        final vertex = glCreateShader(GL_VERTEX_SHADER);
        glShaderBinary(1, [ vertex ], GL_SHADER_BINARY_FORMAT_SPIR_V, _spirv.getData(), _spirv.length);
        glSpecializeShader(vertex, 'main', 0, [ 0 ], [ 0 ]);

        return vertex;
    }

    function fragmentFromSPIRV(_spirv : Bytes) : Int
    {
        final fragment = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderBinary(1, [ fragment ], GL_SHADER_BINARY_FORMAT_SPIR_V, _spirv.getData(), _spirv.length);
        glSpecializeShader(fragment, 'main', 0, [ 0 ], [ 0 ]);

        return fragment;
    }

    function vertexFromSource(_source : String) : Int
    {
        final vertex = glCreateShader(GL_VERTEX_SHADER);
        WebGL.shaderSource(vertex, _source);
        glCompileShader(vertex);

        if (WebGL.getShaderParameter(vertex, GL_COMPILE_STATUS) == 0)
        {
            throw new OGL4VertexCompilationError(WebGL.getShaderInfoLog(vertex));
        }

        return vertex;
    }

    function fragmentFromSource(_source : String) : Int
    {
        var fragment = glCreateShader(GL_FRAGMENT_SHADER);
        WebGL.shaderSource(fragment, _source);
        glCompileShader(fragment);

        if (WebGL.getShaderParameter(fragment, GL_COMPILE_STATUS) == 0)
        {
            throw new OGL4FragmentCompilationError(WebGL.getShaderInfoLog(fragment));
        }

        return fragment;
    }

    /**
     * Free the GPU resources used by a shader program.
     * @param _resource Shader resource to remove.
     */
    function removeShader(_id : ResourceID)
    {
        glDeleteProgram(shaderPrograms[_id]);

        shaderPrograms.remove(_id);
        shaderUniforms.remove(_id);
    }

    /**
     * Create a texture from a resource.
     * @param _resource Image resource to create the texture from.
     */
    function createTexture(_resource : ImageResource)
    {
        var ids = [ 0 ];
        glCreateTextures(GL_TEXTURE_2D, 1, ids);

        glTextureParameteri(ids[0], GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTextureParameteri(ids[0], GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTextureParameteri(ids[0], GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTextureParameteri(ids[0], GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        glTextureStorage2D(ids[0], 1, GL_RGBA8, _resource.width, _resource.height);
        glTextureSubImage2D(ids[0], 0, 0, 0, _resource.width, _resource.height, _resource.format.getPixelFormat(), GL_UNSIGNED_BYTE, _resource.pixels);

        textureInfo[_resource.id] = new TextureInformation(_resource.width, _resource.height);
        textureObjects[_resource.id] = ids[0];
        samplerObjects[_resource.id] = new Map();
    }

    /**
     * Free the GPU resources used by a texture.
     * @param _resource Image resource to remove.
     */
    function removeTexture(_id : ResourceID)
    {
        glDeleteTextures(1, [ textureObjects[_id] ]);

        for (_ => sampler in samplerObjects[_id])
        {
            glDeleteSamplers(1, [ sampler ]);
        }

        if (framebufferObjects.exists(_id))
        {
            glDeleteFramebuffers(1, [ framebufferObjects[_id] ]);
        }

        textureObjects.remove(_id);
        samplerObjects.remove(_id);
        framebufferObjects.remove(_id);
    }

    // #endregion

    // #region State Management

    /**
     * Update the openGL state so it can draw the provided command.
     * @param _command      Command to set the state for.
     * @param _enableStats If stats are to be recorded.
     */
    function updateState(_command : DrawCommand)
    {
        updateFramebuffer(_command.target);
        updateShader(_command.shader);
        updateTextures(_command.shader, _command.textures, _command.samplers);
        updateDepth(_command.depth);
        updateStencil(_command.stencil);
        updateBlending(_command.blending);

        // If the camera does not specify a viewport (non orthographic) then the full size of the target is used.
        switch _command.camera.viewport
        {
            case None:
                switch target
                {
                    case Backbuffer:
                        updateViewport(0, 0, backbuffer.width, backbuffer.height);
                    case Texture(_image):
                        final info = textureInfo[_image];

                        updateViewport(0, 0, info.width, info.height);
                }
            case Viewport(_x, _y, _width, _height):
                updateViewport(_x, _y, _width, _height);
        }

        // If the camera does not specify a clip rectangle then the full size of the target is used.
        switch _command.clip
        {
            case None:
                switch target
                {
                    case Backbuffer:
                        updateClip(0, 0, backbuffer.width, backbuffer.height);
                    case Texture(_image):
                        final info = textureInfo[_image];

                        updateClip(0, 0, info.width, info.height);
                }
            case Clip(_x, _y, _width, _height):
                updateClip(_x, _y, _width, _height);
        }
    }

    /**
     * Either sets the framebuffer to the backbuffer or to an uploaded texture.
     * If the texture has not yet had a framebuffer generated for it, it is done on demand.
     * This could be something which is done on texture creation in the future.
     * @param _newTarget New target
     */
    function updateFramebuffer(_newTarget : TargetState)
    {
        switch _newTarget
        {
            case Backbuffer:
                switch target
                {
                    case Backbuffer: // no change in target
                    case Texture(_):
                        glBindFramebuffer(GL_FRAMEBUFFER, backbuffer.framebuffer);
                }
            case Texture(_requested):
                switch target
                {
                    case Backbuffer:
                        updateTextureFramebuffer(_requested);
                    case Texture(_current):
                        if (_current != _requested)
                        {
                            updateTextureFramebuffer(_requested);
                        }
                }
        }

        target = _newTarget;
    }

    function updateShader(_newShader : ResourceID)
    {
        if (_newShader != shader)
        {
            glUseProgram(shaderPrograms[_newShader]);

            shader = _newShader;
        }
    }

    function updateTextures(_shader : ResourceID, _textures : ReadOnlyArray<ResourceID>, _samplers : ReadOnlyArray<SamplerState>)
    {
        // If the shader description specifies more textures than the command provides throw an exception.
        // If less is specified than provided we just ignore the extra, maybe we should throw as well?
        final info  = shaderUniforms[_shader];
        final count = info.layout.textures.length;

        if (count >= _textures.length)
        {
            // then go through each texture and bind it if it isn't already.
            for (i in 0..._textures.length)
            {
                // Bind and activate the texture if its not already bound.
                final glTextureID = textureObjects.get(_textures[i]);

                if (glTextureID != textureSlots[i])
                {
                    glActiveTexture(GL_TEXTURE0 + i);
                    glBindTexture(GL_TEXTURE_2D, glTextureID);

                    textureSlots[i] = glTextureID;
                }

                // Fetch the custom sampler (first create it if a hash of the sampler is not found).
                var currentSampler = defaultSampler;
                if (i < _samplers.length)
                {
                    final samplerHash     = _samplers[i].hash();
                    final textureSamplers = samplerObjects[_textures[i]];

                    if (!textureSamplers.exists(samplerHash))
                    {
                        textureSamplers[samplerHash] = createSamplerObject(_samplers[i]);
                    }

                    currentSampler = textureSamplers[samplerHash];
                }

                // If its not already bound bind it and update the bound sampler array.
                if (currentSampler != samplerSlots[i])
                {
                    glBindSampler(i, currentSampler);

                    samplerSlots[i] = currentSampler;
                }
            }
        }
        else
        {
            throw new OGL4NotEnoughTexturesException(count, _textures.length);
        }
    }

    function updateClip(_x : Int, _y : Int, _width : Int, _height : Int)
    {
        if (clip.x != _x || clip.y != _y || clip.w != _width || clip.h != _width)
        {
            glScissor(_x, _y, _width, _height);

            clip.set(_x, _y, _width, _height);
        }
    }

    function updateViewport(_x : Int, _y : Int, _width : Int, _height : Int)
    {
        if (viewport.x != _x || viewport.y != _y || viewport.w != _width || viewport.h != _height)
        {
            glViewport(_x, _y, _width, _height);

            viewport.set(_x, _y, _width, _height);
        }
    }

    function updateDepth(_newDepth : DepthState)
    {
        if (!_newDepth.equals(depth))
        {
            if (!_newDepth.depthTesting)
            {
                glDisable(GL_DEPTH_TEST);
            }
            else
            {
                if (_newDepth.depthTesting != depth.depthTesting)
                {
                    glEnable(GL_DEPTH_TEST);
                }
                if (_newDepth.depthMasking != depth.depthMasking)
                {
                    glDepthMask(_newDepth.depthMasking);
                }
                if (_newDepth.depthFunction != depth.depthFunction)
                {
                    glDepthFunc(_newDepth.depthFunction.getComparisonFunc());
                }
            }

            depth.copyFrom(_newDepth);
        }
    }

    function updateStencil(_newStencil : StencilState)
    {
        if (!_newStencil.equals(stencil))
        {
            if (!_newStencil.stencilTesting)
            {
                glDisable(GL_STENCIL_TEST);
            }
            else
            {
                if (_newStencil.stencilTesting != stencil.stencilTesting)
                {
                    glEnable(GL_STENCIL_TEST);
                }

                // Front tests
                if (_newStencil.stencilFrontMask != stencil.stencilFrontMask)
                {
                    glStencilMaskSeparate(GL_FRONT, _newStencil.stencilFrontMask);
                }
                if (_newStencil.stencilFrontFunction != stencil.stencilFrontFunction)
                {
                    glStencilFuncSeparate(GL_FRONT, _newStencil.stencilFrontFunction.getComparisonFunc(), 1, 0xff);
                }
                if (_newStencil.stencilFrontTestFail != stencil.stencilFrontTestFail ||
                    _newStencil.stencilFrontDepthTestFail != stencil.stencilFrontDepthTestFail ||
                    _newStencil.stencilFrontDepthTestPass != stencil.stencilFrontDepthTestPass)
                {
                    glStencilOpSeparate(
                        GL_FRONT,
                        _newStencil.stencilFrontTestFail.getStencilFunc(),
                        _newStencil.stencilFrontDepthTestFail.getStencilFunc(),
                        _newStencil.stencilFrontDepthTestPass.getStencilFunc());
                }

                // Back tests
                if (_newStencil.stencilBackMask != stencil.stencilBackMask)
                {
                    glStencilMaskSeparate(GL_BACK, _newStencil.stencilBackMask);
                }
                if (_newStencil.stencilBackFunction != stencil.stencilBackFunction)
                {
                    glStencilFuncSeparate(GL_BACK, _newStencil.stencilBackFunction.getComparisonFunc(), 1, 0xff);
                }
                if (_newStencil.stencilBackTestFail != stencil.stencilBackTestFail ||
                    _newStencil.stencilBackDepthTestFail != stencil.stencilBackDepthTestFail ||
                    _newStencil.stencilBackDepthTestPass != stencil.stencilBackDepthTestPass)
                {
                    glStencilOpSeparate(
                        GL_BACK,
                        _newStencil.stencilBackTestFail.getStencilFunc(),
                        _newStencil.stencilBackDepthTestFail.getStencilFunc(),
                        _newStencil.stencilBackDepthTestPass.getStencilFunc());
                }
            }

            stencil.copyFrom(_newStencil);
        }
    }

    function updateBlending(_newBlend : BlendState)
    {
        if (!_newBlend.equals(blend))
        {
            if (_newBlend.enabled)
            {
                if (!blend.enabled)
                {
                    glEnable(GL_BLEND);
                }

                glBlendFuncSeparate(
                    _newBlend.srcRGB.getBlendMode(),
                    _newBlend.dstRGB.getBlendMode(),
                    _newBlend.srcAlpha.getBlendMode(),
                    _newBlend.dstAlpha.getBlendMode());
            }
            else
            {
                glDisable(GL_BLEND);
            }

            blend.copyFrom(_newBlend);
        }
    }

    /**
     * Bind a framebuffer from the provided image resource.
     * If a framebuffer does not exist for the image, create one and store it.
     * @param _image Image to bind a framebuffer for.
     */
    function updateTextureFramebuffer(_id : ResourceID)
    {
        if (framebufferObjects.exists(_id))
        {
            glBindFramebuffer(GL_FRAMEBUFFER, framebufferObjects[_id]);
        }
        else
        {
            var fbo = [ 0 ];
            glCreateFramebuffers(1, fbo);
            glNamedFramebufferTexture(fbo[0], GL_COLOR_ATTACHMENT0, textureObjects[_id], 0);

            if (glCheckNamedFramebufferStatus(fbo[0], GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            {
                throw new OGL4IncompleteFramebufferException(Std.string(_id));
            }

            framebufferObjects[_id] = fbo[0];
            glBindFramebuffer(GL_FRAMEBUFFER, fbo[0]);
        }
    }

    /**
     * Creates a new openGL sampler object from a flurry sampler state instance.
     * @param _sampler State to create an openGL sampler from.
     * @return OpenGL sampler object.
     */
    function createSamplerObject(_sampler : SamplerState) : Int
    {
        var samplers = [ 0 ];
        glGenSamplers(1, samplers);
        glSamplerParameteri(samplers[0], GL_TEXTURE_MAG_FILTER, _sampler.minification.getFilterType());
        glSamplerParameteri(samplers[0], GL_TEXTURE_MIN_FILTER, _sampler.magnification.getFilterType());
        glSamplerParameteri(samplers[0], GL_TEXTURE_WRAP_S, _sampler.uClamping.getEdgeClamping());
        glSamplerParameteri(samplers[0], GL_TEXTURE_WRAP_T, _sampler.vClamping.getEdgeClamping());

        return samplers[0];
    }

    function createBackbuffer(_width : Int, _height : Int, _remove : Bool = true) : BackBuffer
    {
        if (_remove)
        {
            glDeleteTextures(1, [ backbuffer.texture ]);
            glDeleteRenderbuffers(1, [ backbuffer.depthStencil ]);
            glDeleteFramebuffers(1, [ backbuffer.framebuffer ]);
        }

        var tex = [ 0 ];
        glCreateTextures(GL_TEXTURE_2D, 1, tex);
        glTextureStorage2D(tex[0], 1, GL_RGB8, _width, _height);

        var rbo = [ 0 ];
        glCreateRenderbuffers(1, rbo);
        glNamedRenderbufferStorage(rbo[0], GL_DEPTH24_STENCIL8, _width, _height);

        var fbo = [ 0 ];
        glCreateFramebuffers(1, fbo);
        glNamedFramebufferTexture(fbo[0], GL_COLOR_ATTACHMENT0, tex[0], 0);
        glNamedFramebufferRenderbuffer(fbo[0], GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo[0]);

        if (glCheckNamedFramebufferStatus(fbo[0], GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            throw new OGL4IncompleteFramebufferException('backbuffer');
        }

        if (target == null)
        {
            glBindFramebuffer(GL_FRAMEBUFFER, fbo[0]);
        }

        return new BackBuffer(_width, _height, 1, tex[0], rbo[0], fbo[0]);
    }

    /**
     * Finds the first shader block with the provided name.
     * If no matching block is found an exception is thrown.
     * @param _name Name to look for.
     * @param _blocks Array of all shader blocks.
     * @return Index into the array of blocks to the first matching block.
     */
    function findBlockIndexByName(_name : String, _blocks : ReadOnlyArray<ShaderBlock>) : Int
    {
        for (i in 0..._blocks.length)
        {
            if (_blocks[i].name == _name)
            {
                return i;
            }
        }

        throw new OGL4UniformBlockNotFoundException(_name);
    }

    // #endregion
}

/**
 * Representation of the backbuffer.
 */
private class BackBuffer
{
    public final width : Int;

    public final height : Int;

    public final scale : Float;

    public final texture : Int;

    public final depthStencil : Int;

    public final framebuffer : Int;

    public function new(_width : Int, _height : Int, _scale : Float, _tex : Int, _depthStencil : Int, _fbo : Int)
    {
        width        = _width;
        height       = _height;
        scale        = _scale;
        texture      = _tex;
        depthStencil = _depthStencil;
        framebuffer  = _fbo;
    }
}

/**
 * Stores the location of all a shaders uniforms
 */
private class ShaderInformation
{
    /**
     * Layout of the shader.
     */
    public final layout : ShaderLayout;

    /**
     * Location of all texture uniforms.
     */
    public final textureLocations : Array<Int>;

    /**
     * Binding point of all shader blocks.
     */
    public final blockBindings : Array<Int>;

    public function new(_layout, _textureLocations, _blockBindings)
    {
        layout           = _layout;
        textureLocations = _textureLocations;
        blockBindings    = _blockBindings;
    }
}

private class TextureInformation
{
    public final width : Int;

    public final height : Int;

    public function new(_width, _height)
    {
        width  = _width;
        height = _height;
    }
}

/**
 * Very simple wrapper around a GLSync object.
 * Needed to work around hxcpp's weirdness with native types in haxe arrays.
 */
private class GLSyncWrapper
{
    public var sync : Null<GLSync>;

    public function new()
    {
        sync   = null;
    }
}

private class OGL4FailedToLoad extends Exception
{
    public function new()
    {
        super('Failed to load OpenGL library');
    }
}

private class OGL4FailedToWaitForSyncObject extends Exception
{
    public function new(_error : Int)
    {
        super('Failed to wait for OpenGL sync object : $_error');
    }
}

private class OGL4NoShaderSourceException extends Exception
{
    public function new(_id : String)
    {
        super('$_id does not contain source code for a openGL 4.6 shader');
    }
}

private class OGL4VertexCompilationError extends Exception
{
    public function new(_error : String)
    {
        super('Unable to compile the vertex shader : $_error');
    }
}

private class OGL4FragmentCompilationError extends Exception
{
    public function new(_error : String)
    {
        super('Unable to compile the fragment shader for : $_error');
    }
}

private class OGL4ShaderLinkingException extends Exception
{
    public function new(_id : String, _error : String)
    {
        super('Unable to link a shader from $_id : $_error');
    }
}

private class OGL4IncompleteFramebufferException extends Exception
{
    public function new(_error : String)
    {
        super(_error);
    }
}

private class OGL4NotEnoughTexturesException extends Exception
{
    public function new(_expected : Int, _actual : Int)
    {
        super('Shader expects $_expected textures but the draw command only provided $_actual');
    }
}

private class OGL4UniformBlockNotFoundException extends Exception
{
    public function new(_blockName)
    {
        super('Unable to find a uniform block with the name $_blockName');
    }
}

private class OGL4CameraViewportNotSetException extends Exception
{
    public function new()
    {
        super('A viewport must be defined for orthographic cameras');
    }
}
