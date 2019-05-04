package uk.aidanlee.flurry.api.gpu.backend;

import haxe.io.Bytes;
import haxe.io.Float32Array;
import haxe.io.UInt32Array;
import haxe.io.UInt16Array;
import haxe.ds.Map;
import cpp.Stdlib;
import cpp.Float32;
import cpp.UInt16;
import cpp.Int32;
import cpp.UInt64;
import cpp.UInt8;
import cpp.Pointer;
import sdl.GLContext;
import sdl.Window;
import sdl.SDL;
import opengl.GL.*;
import opengl.GL.GLSync;
import opengl.WebGL;
import uk.aidanlee.flurry.FlurryConfig.FlurryRendererConfig;
import uk.aidanlee.flurry.FlurryConfig.FlurryWindowConfig;
import uk.aidanlee.flurry.api.gpu.geometry.Blending.BlendMode;
import uk.aidanlee.flurry.api.gpu.geometry.Geometry.PrimitiveType;
import uk.aidanlee.flurry.api.gpu.batcher.DrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.GeometryDrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.BufferDrawCommand;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.maths.Matrix;
import uk.aidanlee.flurry.api.display.DisplayEvents;
import uk.aidanlee.flurry.api.resources.Resource.ShaderType;
import uk.aidanlee.flurry.api.resources.Resource.ShaderLayout;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderBlock;
import uk.aidanlee.flurry.api.resources.ResourceEvents;

using Safety;
using cpp.NativeArray;

class OGL4Backend implements IRendererBackend
{
    /**
     * The number of floats in each vertex.
     */
    static final VERTEX_FLOAT_SIZE = 9;

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
     * Access to the renderer who owns this backend.
     */
    final rendererStats : RendererStats;

    /**
     * If we will be using bindless textures.
     */
    final bindless : Bool;

    /**
     * The single VBO used by the backend.
     */
    final glVbo : Int;

    /**
     * The single Index buffer used by the backend.
     */
    final glIbo : Int;

    /**
     * The single VAO which is bound once when the backend is created.
     */
    final glVao : Int;

    /**
     * Backbuffer display, default target if none is specified.
     */
    final backbuffer : BackBuffer;

    final streamStorage : StreamBufferManager;

    final staticStorage : StaticBufferManager;

    /**
     * Constant vector instance which is used to transform vertices when copying into the vertex buffer.
     */
    final transformationVector : Vector;

    /**
     * Constant identity matrix, used as the model matrix for non multi draw shaders.
     */
    final identityMatrix : Matrix;

    /**
     * Index pointing to the current writable vertex buffer range.
     */
    var vertexBufferRangeIndex : Int;

    /**
     * Index pointing to the current writing index buffer range.
     */
    var indexBufferRangeIndex : Int;

    /**
     * The index into the vertex buffer to write.
     * Writing more floats must increment this value. Set the to current ranges offset in preDraw.
     */
    var vertexFloatOffset : Int;

    /**
     * Offset to use when calling openngl draw commands.
     * Writing more verticies must increment this value. Set the to current ranges offset in preDraw.
     */
    var vertexOffset : Int;

    /**
     * The current index position into the index buffer we are writing to.
     * Like vertexOffset at the beginning of each frame it is set to an initial offset into the index buffer.
     */
    var indexOffset : Int;

    /**
     * The number of bytes into the index buffer we are writing to.
     */
    var indexByteOffset : Int;

    /**
     * Shader programs keyed by their associated shader resource IDs.
     */
    final shaderPrograms : Map<String, Int>;

    /**
     * Shader uniform locations keyed by their associated shader resource IDs.
     */
    final shaderUniforms : Map<String, ShaderLocations>;

    /**
     * Texture objects keyed by their associated image resource IDs.
     */
    final textureObjects : Map<String, Int>;

    /**
     * 64bit texture handles keyed by their associated image resource IDs.
     * This will not be used if bindless is false.
     */
    final textureHandles : Map<String, haxe.Int64>;

    /**
     * Framebuffer objects keyed by their associated image resource IDs.
     * Framebuffers will only be generated when an image resource is used as a target.
     * Will be destroyed when the associated image resource is destroyed.
     */
    final framebufferObjects : Map<String, Int>;

    final rangeSyncPrimitives : Array<GLSyncWrapper>;

    var currentRange : Int;

    // GL state variables

    /**
     * The current viewport size.
     */
    var viewport : Rectangle;

    /**
     * The current scissor region size.
     */
    var clip : Rectangle;

    /**
     * The target to use. If null the backbuffer is used.
     */
    var target : ImageResource;

    /**
     * Shader to use.
     */
    var shader : ShaderResource;

    /**
     * The bound ssbo buffer.
     */
    var ssbo : Int;

    /**
     * The bound indirect command buffer.
     */
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
    public function new(_resourceEvents : ResourceEvents, _displayEvents : DisplayEvents, _rendererStats : RendererStats, _windowConfig : FlurryWindowConfig, _rendererConfig : FlurryRendererConfig)
    {
        createWindow(_windowConfig);

        resourceEvents = _resourceEvents;
        displayEvents  = _displayEvents;
        rendererStats  = _rendererStats;

        // Check for ARB_bindless_texture support
        bindless = SDL.GL_ExtensionSupported('GL_ARB_bindless_texutre');

        var staticVertexBuffer = _rendererConfig.unchangingVertices;
        var streamVertexBuffer = _rendererConfig.dynamicVertices;
        var staticIndexBuffer  = _rendererConfig.unchangingIndices;
        var streamIndexBuffer  = _rendererConfig.dynamicIndices;

        // Create two empty buffers, for the vertex and index data
        var buffers = [ 0, 0 ];
        glCreateBuffers(2, buffers);

        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", buffers[0], staticVertexBuffer * 9 * 4 + ((streamVertexBuffer * 9 * 4) * 3), GL_DYNAMIC_STORAGE_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
        untyped __cpp__("glNamedBufferStorage({0}, {1}, nullptr, {2})", buffers[1], staticIndexBuffer * 2  + ((streamIndexBuffer * 2) * 3), GL_DYNAMIC_STORAGE_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);

        // Create the vao and bind the vbo to it.
        var vao = [ 0 ];
        glCreateVertexArrays(1, vao);
        glVertexArrayVertexBuffer(vao[0], 0, buffers[0], 0, Float32Array.BYTES_PER_ELEMENT * VERTEX_FLOAT_SIZE);

        // Enable and setup the vertex attributes for this batcher.
        glEnableVertexArrayAttrib(vao[0], 0);
        glEnableVertexArrayAttrib(vao[0], 1);
        glEnableVertexArrayAttrib(vao[0], 2);

        glVertexArrayAttribFormat(buffers[0], 0, 3, GL_FLOAT, false, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_POS);
        glVertexArrayAttribFormat(buffers[0], 1, 4, GL_FLOAT, false, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_COL);
        glVertexArrayAttribFormat(buffers[0], 2, 2, GL_FLOAT, false, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_TEX);

        glVertexArrayAttribBinding(vao[0], 0, 0);
        glVertexArrayAttribBinding(vao[0], 1, 0);
        glVertexArrayAttribBinding(vao[0], 2, 0);

        glVbo = buffers[0];
        glIbo = buffers[1];
        glVao = vao[0];

        // Bind our VAO once.
        glBindVertexArray(glVao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, glIbo);

        // Map the streaming parts of the vertex and index buffer.
        var vtxBuffer : Pointer<UInt8> = Pointer.fromRaw(glMapNamedBufferRange(glVbo, staticVertexBuffer * 9 * 4, (streamVertexBuffer * 9 * 4) * 3, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();
        var idxBuffer : Pointer<UInt8> = Pointer.fromRaw(glMapNamedBufferRange(glIbo, staticIndexBuffer * 2     , (streamIndexBuffer * 2) * 3     , GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)).reinterpret();

        transformationVector = new Vector();
        identityMatrix       = new Matrix();
        streamStorage        = new StreamBufferManager(staticVertexBuffer, staticIndexBuffer, streamVertexBuffer, streamIndexBuffer, vtxBuffer, idxBuffer);
        staticStorage        = new StaticBufferManager(staticVertexBuffer, staticIndexBuffer, glVbo, glIbo);
        rangeSyncPrimitives  = [ for (i in 0...3) new GLSyncWrapper() ];
        currentRange         = 0;

        // Create a representation of the backbuffer and manually insert it into the target structure.
        var backbufferID = [ 0 ];
        glGetIntegerv(GL_FRAMEBUFFER, backbufferID);

        backbuffer = new BackBuffer(_windowConfig.width, _windowConfig.height, 1, backbufferID[0]);

        // Default blend mode
        // TODO : Move this to be a settable property in the geometry or renderer or something
        glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO);

        // Set the clear colour
        glClearColor(_rendererConfig.clearColour.r, _rendererConfig.clearColour.g, _rendererConfig.clearColour.b, _rendererConfig.clearColour.a);

        // Default scissor test
        glEnable(GL_SCISSOR_TEST);
        glScissor(0, 0, backbuffer.width, backbuffer.height);

        // default state
        viewport = new Rectangle(0, 0, backbuffer.width, backbuffer.height);
        clip     = new Rectangle(0, 0, backbuffer.width, backbuffer.height);
        target   = null;
        shader   = null;
        ssbo     = 0;
        cmds     = 0;

        shaderPrograms     = [];
        shaderUniforms     = [];
        textureObjects     = [];
        textureHandles     = [];
        framebufferObjects = [];

        resourceEvents.created.add(onResourceCreated);
        resourceEvents.removed.add(onResourceRemoved);
        displayEvents.sizeChanged.add(onSizeChanged);
        displayEvents.changeRequested.add(onChangeRequest);
    }

    /**
     * Clears the display with the colour bit.
     */
    public function clear()
    {
        //
    }

    /**
     * Unlock the range we will be writing into and set the offsets to that of the range.
     */
    public function preDraw()
    {
        if (rangeSyncPrimitives[currentRange].sync != null)
        {
            while (true)
            {
                var waitReturn = glClientWaitSync(rangeSyncPrimitives[currentRange].sync, GL_SYNC_FLUSH_COMMANDS_BIT, 1000);
                if (waitReturn == GL_ALREADY_SIGNALED || waitReturn == GL_CONDITION_SATISFIED)
                {
                    break;
                }
            }
        }

        streamStorage.unlockBuffers(currentRange);

        // Disable the clip to clear the entire target.
        clip.set(0, 0, backbuffer.width, backbuffer.height);
        glScissor(0, 0, backbuffer.width, backbuffer.height);

        glClear(GL_COLOR_BUFFER_BIT);
    }

    /**
     * Upload a series of geometry commands into the current buffer range.
     * @param _commands Commands to upload.
     */
    public function uploadGeometryCommands(_commands : Array<GeometryDrawCommand>)
    {
        for (command in _commands)
        {
            switch (command.uploadType)
            {
                case Static : staticStorage.uploadGeometry(command);
                case Stream, Immediate : streamStorage.uploadGeometry(command);
            }
        }
    }

    /**
     * Upload a series of buffer commands into the current buffer range.
     * @param _commands Buffer commands.
     */
    public function uploadBufferCommands(_commands : Array<BufferDrawCommand>)
    {
        for (command in _commands)
        {
            switch (command.uploadType)
            {
                case Static : staticStorage.uploadBuffer(command);
                case Stream, Immediate : streamStorage.uploadBuffer(command);
            }
        }
    }

    /**
     * Submit a series of uploaded commands to be drawn.
     * @param _commands    Commands to draw.
     * @param _recordStats If stats are to be recorded.
     */
    public function submitCommands(_commands : Array<DrawCommand>, _recordStats : Bool = true)
    {
        for (command in _commands)
        {
            setState(command, _recordStats);

            switch (command.uploadType)
            {
                case Static : staticStorage.draw(command);
                case Stream, Immediate : streamStorage.draw(command);
            }
        }
    }

    /**
     * Locks the range we are currenly writing to and increments the index.
     */
    public function postDraw()
    {
        if (rangeSyncPrimitives[currentRange].sync != null)
        {
            glDeleteSync(rangeSyncPrimitives[currentRange].sync);
        }

        rangeSyncPrimitives[currentRange].sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        currentRange = (currentRange + 1) % 3;

        SDL.GL_SwapWindow(window);
    }

    /**
     * Unmap the buffer and iterate over all resources deleting their resources and remove them from the structure.
     */
    public function cleanup()
    {
        resourceEvents.created.remove(onResourceCreated);
        resourceEvents.removed.remove(onResourceRemoved);
        displayEvents.sizeChanged.remove(onSizeChanged);
        displayEvents.changeRequested.remove(onChangeRequest);

        glUnmapNamedBuffer(glVbo);

        for (shaderID in shaderPrograms.keys())
        {
            glDeleteProgram(shaderPrograms.get(shaderID));

            shaderPrograms.remove(shaderID);
            shaderUniforms.remove(shaderID);
        }

        for (textureID in textureObjects.keys())
        {
            if (bindless)
            {
                glMakeTextureHandleNonResidentARB(cast textureHandles.get(textureID));
                textureHandles.remove(textureID);
            }

            glDeleteTextures(1, [ textureObjects.get(textureID) ]);
            textureObjects.remove(textureID);

            if (framebufferObjects.exists(textureID))
            {
                glDeleteFramebuffers(1, [ framebufferObjects.get(textureID) ]);
                framebufferObjects.remove(textureID);
            }
        }

        SDL.GL_DeleteContext(glContext);
        SDL.destroyWindow(window);
    }

    // #region SDL Window Management

    function createWindow(_options : FlurryWindowConfig)
    {        
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

        window    = SDL.createWindow('Flurry', SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, _options.width, _options.height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
        glContext = SDL.GL_CreateContext(window);

        SDL.GL_MakeCurrent(window, glContext);

        // TODO : Error handling if GLEW doesn't return OK.
        glew.GLEW.init();

        // flushing `GL_INVALID_ENUM` error which GLEW generates if `glewExperimental` is true.
        glGetError();
    }

    function onChangeRequest(_event : DisplayEventChangeRequest)
    {
        SDL.setWindowSize(window, _event.width, _event.height);
        SDL.setWindowFullscreen(window, _event.fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
        SDL.GL_SetSwapInterval(_event.vsync ? 1 : 0);
    }

    function onSizeChanged(_event : DisplayEventData)
    {
        backbuffer.width  = _event.width;
        backbuffer.height = _event.height;
    }

    // #endregion

    // #region Resource Management

    function onResourceCreated(_event : ResourceEventCreated)
    {
        switch (_event.type)
        {
            case ImageResource:
                createTexture(cast _event.resource);
            case ShaderResource:
                createShader(cast _event.resource);
            case _:
                //
        }
    }

    function onResourceRemoved(_event : ResourceEventRemoved)
    {
        switch (_event.type)
        {
            case ImageResource:
                removeTexture(cast _event.resource);
            case ShaderResource:
                removeShader(cast _event.resource);
            case _:
                //
        }
    }

    /**
     * Create a shader from a resource.
     * @param _resource Resource to create a shader of.
     */
    function createShader(_resource : ShaderResource)
    {
        if (_resource.ogl4 == null)
        {
            throw 'OpenGL 4.5 Backend Exception : ${_resource.id} : Attempting to create a shader from a resource which has no gl45 shader source';
        }

        if (shaderPrograms.exists(_resource.id))
        {
            throw 'OpenGL 4.5 Backend Exception : ${_resource.id} : Attempting to create a shader which already exists';
        }

        // Create vertex shader.
        var vertex = glCreateShader(GL_VERTEX_SHADER);
        WebGL.shaderSource(vertex, _resource.ogl4.vertex);
        glCompileShader(vertex);

        if (WebGL.getShaderParameter(vertex, GL_COMPILE_STATUS) == 0)
        {
            throw 'OpenGL 4.5 Backend Exception : ${_resource.id} : Error compiling vertex shader : ${WebGL.getShaderInfoLog(vertex)}';
        }

        // Create fragment shader.
        var fragment = glCreateShader(GL_FRAGMENT_SHADER);
        WebGL.shaderSource(fragment, _resource.ogl4.fragment);
        glCompileShader(fragment);

        if (WebGL.getShaderParameter(fragment, GL_COMPILE_STATUS) == 0)
        {
            throw 'OpenGL 4.5 Backend Exception : ${_resource.id} : Error compiling fragment shader : ${WebGL.getShaderInfoLog(fragment)}';
        }

        // Link the shaders into a program.
        var program = glCreateProgram();
        glAttachShader(program, vertex);
        glAttachShader(program, fragment);
        glLinkProgram(program);

        if (WebGL.getProgramParameter(program, GL_LINK_STATUS) == 0)
        {
            throw 'OpenGL 4.5 Backend Exception : ${_resource.id} : Error linking program : ${WebGL.getProgramInfoLog(program)}';
        }

        // Delete the shaders now that they're linked
        glDeleteShader(vertex);
        glDeleteShader(fragment);

        var textureLocations = [ for (t in _resource.layout.textures) glGetUniformLocation(program, t) ];
        var blockLocations   = [ for (b in _resource.layout.blocks) glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, b.name) ];
        var blockBindings    = [ for (i in 0..._resource.layout.blocks.length) _resource.layout.blocks[i].bind ];

        for (i in 0..._resource.layout.blocks.length)
        {
            glShaderStorageBlockBinding(program, blockLocations[i], blockBindings[i]);
        }

        var blockBuffers = [ for (i in 0..._resource.layout.blocks.length) 0 ];
        glCreateBuffers(blockBuffers.length, blockBuffers);
        var blockBytes = [ for (i in 0..._resource.layout.blocks.length) generateUniformBlock(_resource.layout.blocks[i], blockBuffers[i], blockBindings[i]) ];

        glBindBuffersBase(GL_SHADER_STORAGE_BUFFER, blockBindings[0], blockBindings.length, blockBuffers);

        shaderPrograms.set(_resource.id, program);
        shaderUniforms.set(_resource.id, new ShaderLocations(_resource.layout, textureLocations, blockBindings, blockBuffers, blockBytes));
    }

    /**
     * Free the GPU resources used by a shader program.
     * @param _resource Shader resource to remove.
     */
    function removeShader(_resource : ShaderResource)
    {
        glDeleteProgram(shaderPrograms.get(_resource.id));

        shaderPrograms.remove(_resource.id);
        shaderUniforms.remove(_resource.id);
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
        glTextureSubImage2D(ids[0], 0, 0, 0, _resource.width, _resource.height, GL_BGRA, GL_UNSIGNED_BYTE, _resource.pixels);

        textureObjects.set(_resource.id, ids[0]);

        if (bindless)
        {
            var handle = glGetTextureHandleARB(ids[0]);
            glMakeTextureHandleResidentARB(handle);

            textureHandles.set(_resource.id, handle);
        }
    }

    /**
     * Free the GPU resources used by a texture.
     * @param _resource Image resource to remove.
     */
    function removeTexture(_resource : ImageResource)
    {
        if (bindless)
        {
            glMakeTextureHandleNonResidentARB(cast textureHandles.get(_resource.id));
            textureHandles.remove(_resource.id);
        }

        glDeleteTextures(1, [ textureObjects.get(_resource.id) ]);
        textureObjects.remove(_resource.id);
    }

    function generateUniformBlock(_block : ShaderBlock, _buffer : Int, _binding : Int) : Bytes
    {
        var blockSize = 0;
        for (val in _block.vals)
        {
            switch (ShaderType.createByName(val.type))
            {
                case Matrix4: blockSize += 64;
                case Vector4: blockSize += 16;
                case Int, Float: blockSize += 4;
            }
        }

        var bytes = Bytes.alloc(blockSize);
        glNamedBufferData(_buffer, bytes.length, bytes.getData(), GL_DYNAMIC_DRAW);
        
        return bytes;
    }

    // #endregion

    // #region State Management

    /**
     * Update the openGL state so it can draw the provided command.
     * @param _command      Command to set the state for.
     * @param _enableStats If stats are to be recorded.
     */
    function setState(_command : DrawCommand, _enableStats : Bool)
    {
        // Set the viewport.
        // If the viewport of the command is null then the backbuffer size is used (size of the window).
        var cmdViewport = _command.viewport != null ? _command.viewport : new Rectangle(0, 0, backbuffer.width, backbuffer.height);
        if (!viewport.equals(cmdViewport))
        {
            viewport.set(cmdViewport.x, cmdViewport.y, cmdViewport.w, cmdViewport.h);

            var x = viewport.x *= target == null ? backbuffer.viewportScale : 1;
            var y = viewport.y *= target == null ? backbuffer.viewportScale : 1;
            var w = viewport.w *= target == null ? backbuffer.viewportScale : 1;
            var h = viewport.h *= target == null ? backbuffer.viewportScale : 1;

            // OpenGL works 0x0 is bottom left so we need to flip the y.
            y = (target == null ? backbuffer.height : target.height) - (y + h);
            glViewport(Std.int(x), Std.int(y), Std.int(w), Std.int(h));

            if (_enableStats)
            {
                rendererStats.viewportSwaps++;
            }
        }

        // Apply the scissor clip.
        if (!_command.clip.equals(clip))
        {
            clip.copyFrom(_command.clip);

            var x = clip.x * (target == null ? backbuffer.viewportScale : 1);
            var y = clip.y * (target == null ? backbuffer.viewportScale : 1);
            var w = clip.w * (target == null ? backbuffer.viewportScale : 1);
            var h = clip.h * (target == null ? backbuffer.viewportScale : 1);

            // If the clip rectangle has an area of 0 then set the width and height to that of the viewport
            // This essentially disables clipping by clipping the entire backbuffer size.
            if (clip.area() == 0)
            {
                w = backbuffer.width  * (target == null ? backbuffer.viewportScale : 1);
                h = backbuffer.height * (target == null ? backbuffer.viewportScale : 1);
            }

            // OpenGL works 0x0 is bottom left so we need to flip the y.
            y = (target == null ? backbuffer.height : target.height) - (y + h);
            glScissor(Std.int(x), Std.int(y), Std.int(w), Std.int(h));

            if (_enableStats)
            {
                rendererStats.scissorSwaps++;
            }
        }

        // Set the render target.
        // If the target is null then the backbuffer is used.
        // Render targets are created on the fly as and when needed since most textures probably won't be used as targets.
        if (_command.target != target)
        {
            target = _command.target;

            if (target != null && !framebufferObjects.exists(target.id))
            {
                // Create the framebuffer
                var fbo = [ 0 ];
                glCreateFramebuffers(1, fbo);
                glNamedFramebufferTexture(fbo[0], GL_COLOR_ATTACHMENT0, textureObjects.get(target.id), 0);

                if (glCheckNamedFramebufferStatus(fbo[0], GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
                {
                    throw 'OpenGL 4.5 Backend Exception : ${target.id} : Framebuffer not complete';
                }

                framebufferObjects.set(target.id, fbo[0]);
            }

            glBindFramebuffer(GL_FRAMEBUFFER, target != null ? framebufferObjects.get(target.id) : backbuffer.framebufferObject);

            if (_enableStats)
            {
                rendererStats.targetSwaps++;
            }
        }

        // Apply shader changes.
        if (shader != _command.shader)
        {
            shader = _command.shader;
            glUseProgram(shaderPrograms.get(shader.id));
            
            if (_enableStats)
            {
                rendererStats.shaderSwaps++;
            }
        }
        
        // Update shader blocks and bind any textures required.
        setUniforms(_command, _enableStats);

        // Set the blending
        if (_command.blending)
        {
            glEnable(GL_BLEND);
            glBlendFuncSeparate(getBlendMode(_command.srcRGB), getBlendMode(_command.dstRGB), getBlendMode(_command.srcAlpha), getBlendMode(_command.dstAlpha));

            if (_enableStats)
            {
                rendererStats.blendSwaps++;
            }
        }
        else
        {
            glDisable(GL_BLEND);

            if (_enableStats)
            {
                rendererStats.blendSwaps++;
            }
        }
    }

    /**
     * Apply all of a shaders uniforms.
     * @param _command     Command to set the state for.
     * @param _enableStats If stats are to be recorded.
     */
    function setUniforms(_command : DrawCommand, _enableStats : Bool)
    {
        var cache = shaderUniforms.get(_command.shader.id);
        var preferedUniforms = _command.uniforms.or(_command.shader.uniforms);

        // TEMP : Set all textures all the time.
        // TODO : Store all bound texture IDs and check before binding textures.

        if (cache.layout.textures.length > _command.textures.length)
        {
            throw 'OpenGL 4.5 Backend Exception : ${_command.shader.id} : More textures required by the shader than are provided by the draw command';
        }
        else
        {
            if (bindless)
            {
                var handlesToBind : Array<UInt64> = [ for (texture in _command.textures) cast textureHandles.get(texture.id) ];
                glUniformHandleui64vARB(0, handlesToBind.length, handlesToBind);
            }
            else
            {
                // then go through each texture and bind it if it isn't already.
                var texturesToBind : Array<Int> = [ for (texture in _command.textures) textureObjects.get(texture.id) ];
                glBindTextures(0, texturesToBind.length, texturesToBind);

                if (_enableStats)
                {
                    rendererStats.textureSwaps++;
                }
            }
        }
        
        for (i in 0...cache.layout.blocks.length)
        {
            if (cache.layout.blocks[i].name == 'defaultMatrices')
            {
                // The matrix ssbo used depends on if its a static or stream command
                // stream draws are batched and only have a single model matrix, they use the shaders default matrix ssbo.
                // static draws have individual ssbos for each command. These ssbos fit a model matrix per geometry.
                // The matrix buffer for static draws is uploaded in the static draw manager.
                // 
                // TODO : have static buffer draws use the default shader ssbo?
                switch (_command.uploadType)
                {
                    case Static :
                        var rng = staticStorage.get(_command);
                        var ptr = Pointer.arrayElem(rng.matrixBuffer.view.buffer.getData(), 0);
                        Stdlib.memcpy(ptr          , (_command.projection : Float32Array).view.buffer.getData().address(0), 64);
                        Stdlib.memcpy(ptr.incBy(64), (_command.view       : Float32Array).view.buffer.getData().address(0), 64);
                        glNamedBufferSubData(rng.glMatrixBuffer, 0, rng.matrixBuffer.view.buffer.length, rng.matrixBuffer.view.buffer.getData());

                        if (ssbo != rng.glMatrixBuffer)
                        {
                            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, cache.blockBindings[i], rng.glMatrixBuffer);
                            ssbo = rng.glMatrixBuffer;
                        }
                        if (cmds != rng.glCommandBuffer)
                        {
                            glBindBuffer(GL_DRAW_INDIRECT_BUFFER, rng.glCommandBuffer);
                            cmds = rng.glCommandBuffer;
                        }
                        
                    case Stream, Immediate :
                        var ptr = Pointer.arrayElem(cache.blockBytes[i].getData(), 0);
                        Stdlib.memcpy(ptr          , (_command.projection : Float32Array).view.buffer.getData().address(0), 64);
                        Stdlib.memcpy(ptr.incBy(64), (_command.view       : Float32Array).view.buffer.getData().address(0), 64);
                        Stdlib.memcpy(ptr.incBy(64), (identityMatrix      : Float32Array).view.buffer.getData().address(0), 64);
                        glNamedBufferSubData(cache.blockBuffers[i], 0, cache.blockBytes[i].length, cache.blockBytes[i].getData());

                        if (ssbo != cache.blockBuffers[i])
                        {
                            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, cache.blockBindings[i], cache.blockBuffers[i]);
                            ssbo = cache.blockBuffers[i];
                        }
                }
            }
            else
            {
                var ptr : Pointer<UInt8> = Pointer.arrayElem(cache.blockBytes[i].getData(), 0).reinterpret();

                // Otherwise upload all user specified uniform values.
                // TODO : We should have some sort of error checking if the expected uniforms are not found.
                var pos = 0;
                for (val in cache.layout.blocks[i].vals)
                {
                    switch (ShaderType.createByName(val.type))
                    {
                        case Matrix4:
                            var mat = preferedUniforms.matrix4.exists(val.name) ? preferedUniforms.matrix4.get(val.name) : _command.shader.uniforms.matrix4.get(val.name);
                            Stdlib.memcpy(ptr.incBy(pos), (mat : Float32Array).view.buffer.getData().address(0), 64);
                            pos += 64;
                        case Vector4:
                            var vec = preferedUniforms.vector4.exists(val.name) ? preferedUniforms.vector4.get(val.name) : _command.shader.uniforms.vector4.get(val.name);
                            Stdlib.memcpy(ptr.incBy(pos), (vec : Float32Array).view.buffer.getData().address(0), 16);
                            pos += 16;
                        case Int:
                            var dst : Pointer<Int32> = ptr.reinterpret();
                            dst.setAt(Std.int(pos / 4), preferedUniforms.int.exists(val.name) ? preferedUniforms.int.get(val.name) : _command.shader.uniforms.int.get(val.name));
                            pos += 4;
                        case Float:
                            var dst : Pointer<Float32> = ptr.reinterpret();
                            dst.setAt(Std.int(pos / 4), preferedUniforms.float.exists(val.name) ? preferedUniforms.float.get(val.name) : _command.shader.uniforms.float.get(val.name));
                            pos += 4;
                    }
                }

                glNamedBufferSubData(cache.blockBuffers[i], 0, cache.blockBytes[i].length, cache.blockBytes[i].getData());
            }
        }
    }

    /**
     * Returns the equivalent openGL blend mode from the abstract blend enum
     * @param _mode Blend mode to fetch.
     * @return Int
     */
    function getBlendMode(_mode : BlendMode) : Int
    {
        return switch (_mode)
        {
            case Zero             : GL_ZERO;
            case One              : GL_ONE;
            case SrcAlphaSaturate : GL_SRC_ALPHA_SATURATE;
            case SrcColor         : GL_SRC_COLOR;
            case OneMinusSrcColor : GL_ONE_MINUS_SRC_COLOR;
            case SrcAlpha         : GL_SRC_ALPHA;
            case OneMinusSrcAlpha : GL_ONE_MINUS_SRC_ALPHA;
            case DstAlpha         : GL_DST_ALPHA;
            case OneMinusDstAlpha : GL_ONE_MINUS_DST_ALPHA;
            case DstColor         : GL_DST_COLOR;
            case OneMinusDstColor : GL_ONE_MINUS_DST_COLOR;
            case _: 0;
        }
    }

    // #endregion
}

/**
 * Representation of the backbuffer.
 */
private class BackBuffer
{
    /**
     * Width of the backbuffer.
     */
    public var width : Int;

    /**
     * Height of the backbuffer.
     */
    public var height : Int;

    /**
     * View scale of the backbuffer.
     */
    public var viewportScale : Float;

    /**
     * Framebuffer object for the backbuffer.
     */
    public var framebufferObject : Int;

    public function new(_width : Int, _height : Int, _viewportScale : Float, _framebuffer : Int)
    {
        width             = _width;
        height            = _height;
        viewportScale     = _viewportScale;
        framebufferObject = _framebuffer;
    }
}

/**
 * Stores the location of all a shaders uniforms
 */
private class ShaderLocations
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

    /**
     * SSBO buffer objects.
     */
    public final blockBuffers : Array<Int>;

    /**
     * Bytes for each SSBO buffer.
     */
    public final blockBytes : Array<Bytes>;

    public function new(_layout : ShaderLayout, _textureLocations : Array<Int>, _blockBindings : Array<Int>, _blockBuffers : Array<Int>, _blockBytes : Array<Bytes>)
    {
        layout           = _layout;
        textureLocations = _textureLocations;
        blockBindings    = _blockBindings;
        blockBuffers     = _blockBuffers;
        blockBytes       = _blockBytes;
    }
}

/**
 * Manages a triple buffered stream buffer.
 */
private class StreamBufferManager
{
    final forceIncludeGL : GLSyncWrapper;

    /**
     * Constant vector for transforming vertices before being uploaded.
     */
    final transformationVector : Vector;

    /**
     * The base vertex offset into the buffer that the stream buffer starts.
     */
    final vtxBaseOffset : Int;

    /**
     * The base index offset into the buffer that the stream buffer starts.
     */
    final idxBaseOffset : Int;

    /**
     * The size of each vertex stream range.
     */
    final vtxRangeSize : Int;

    /**
     * The size of each index stream range.
     */
    final idxRangeSize : Int;

    /**
     * Pointer to each range in the vertex stream buffer.
     */
    final vtxBuffer : Pointer<Float32>;

    /**
     * Pointer to each range in the index stream buffer.
     */
    final idxBuffer : Pointer<UInt16>;

    /**
     * Each ranges vertex offset.
     */
    var commandVtxOffsets : Map<Int, Int>;

    /**
     * Each ranges index offset.
     */
    var commandIdxOffsets : Map<Int, Int>;

    /**
     * Current vertex float write position.
     */
    var currentVtxTypePosition : Int;

    /**
     * Current index uint write position.
     */
    var currentIdxTypePosition : Int;

    /**
     * Current vertex write position.
     */
    var currentVertexPosition : Int;

    public function new(_vtxBaseOffset : Int, _idxBaseOffset : Int, _vtxRange : Int, _idxRange : Int, _vtxPtr : Pointer<UInt8>, _idxPtr : Pointer<UInt8>)
    {
        forceIncludeGL         = new GLSyncWrapper();
        transformationVector   = new Vector();
        vtxBaseOffset          = _vtxBaseOffset;
        idxBaseOffset          = _idxBaseOffset;
        vtxRangeSize           = _vtxRange;
        idxRangeSize           = _idxRange;
        vtxBuffer              = _vtxPtr.reinterpret();
        idxBuffer              = _idxPtr.reinterpret();
        commandVtxOffsets      = [];
        commandIdxOffsets      = [];
        currentVtxTypePosition = 0;
        currentIdxTypePosition = 0;
        currentVertexPosition  = 0;
    }

    /**
     * Setup uploading to a specific stream buffer range.
     * Must be done at the beginning off each frame.
     * @param _currentRange Range to upload to.
     */
    public function unlockBuffers(_currentRange : Int)
    {
        currentVtxTypePosition = _currentRange * (vtxRangeSize * 9);
        currentVertexPosition  = _currentRange * vtxRangeSize;
        currentIdxTypePosition = _currentRange * idxRangeSize;
        commandVtxOffsets      = [];
        commandIdxOffsets      = [];
    }

    /**
     * Upload a geometry draw command into the current range.
     * @param _command Command to upload.
     */
    public function uploadGeometry(_command : GeometryDrawCommand)
    {
        commandVtxOffsets.set(_command.id, vtxBaseOffset + currentVertexPosition);
        commandIdxOffsets.set(_command.id, idxBaseOffset + currentIdxTypePosition);

        var commandIndexOffset = 0;

        for (geom in _command.geometry)
        {
            var matrix = geom.transformation.transformation;

            for (index in geom.indices)
            {
                idxBuffer[currentIdxTypePosition++] = commandIndexOffset + index;
            }

            for (vertex in geom.vertices)
            {
                // Copy the vertex into another vertex.
                // This allows us to apply the transformation without permanently modifying the original geometry.
                transformationVector.copyFrom(vertex.position);
                transformationVector.transform(matrix);

                vtxBuffer[currentVtxTypePosition++] = transformationVector.x;
                vtxBuffer[currentVtxTypePosition++] = transformationVector.y;
                vtxBuffer[currentVtxTypePosition++] = transformationVector.z;
                vtxBuffer[currentVtxTypePosition++] = vertex.color.r;
                vtxBuffer[currentVtxTypePosition++] = vertex.color.g;
                vtxBuffer[currentVtxTypePosition++] = vertex.color.b;
                vtxBuffer[currentVtxTypePosition++] = vertex.color.a;
                vtxBuffer[currentVtxTypePosition++] = vertex.texCoord.x;
                vtxBuffer[currentVtxTypePosition++] = vertex.texCoord.y;
            }

            currentVertexPosition += geom.vertices.length;
            commandIndexOffset += geom.vertices.length;
        }
    }

    /**
     * Upload a buffer draw command into the current range.
     * @param _command 
     */
    public function uploadBuffer(_command : BufferDrawCommand)
    {
        commandVtxOffsets.set(_command.id, vtxBaseOffset + currentVertexPosition);
        commandIdxOffsets.set(_command.id, idxBaseOffset + currentIdxTypePosition);

        Stdlib.memcpy(
            idxBuffer.incBy(currentIdxTypePosition),
            Pointer.arrayElem(_command.idxData.view.buffer.getData(), _command.idxStartIndex * 2),
            _command.indices * 2);
        Stdlib.memcpy(
            vtxBuffer.incBy(currentVtxTypePosition),
            Pointer.arrayElem(_command.vtxData.view.buffer.getData(), _command.vtxStartIndex * 9 * 4),
            _command.vertices * 9 * 4);

        idxBuffer.incBy(-currentIdxTypePosition);
        vtxBuffer.incBy(-currentVtxTypePosition);

        currentIdxTypePosition += _command.indices;
        currentVtxTypePosition += _command.vertices * 9;
        currentVertexPosition  += _command.vertices;
    }

    /**
     * Draw an uploaded draw command.
     * @param _command Command to draw.
     */
    public function draw(_command : DrawCommand)
    {
        // Draw the actual vertices
        if (_command.indices > 0)
        {
            var idxOffset = commandIdxOffsets.get(_command.id) * 2;
            var vtxOffset = commandVtxOffsets.get(_command.id);
            untyped __cpp__('glDrawElementsBaseVertex({0}, {1}, {2}, (void*)(intptr_t){3}, {4})', getPrimitiveType(_command.primitive), _command.indices, GL_UNSIGNED_SHORT, idxOffset, vtxOffset);
        }
        else
        {
            var vtxOffset = commandVtxOffsets.get(_command.id);
            glDrawArrays(getPrimitiveType(_command.primitive), vtxOffset, _command.vertices);
        }
    }

    /**
     * Returns an OpenGL primitive constant from a flurry primitive enum.
     * @param _primitive Primitive type.
     * @return Int
     */
    function getPrimitiveType(_primitive : PrimitiveType) : Int
    {
        return switch (_primitive)
        {
            case Points        : GL_POINTS;
            case Lines         : GL_LINES;
            case LineStrip     : GL_LINE_STRIP;
            case Triangles     : GL_TRIANGLES;
            case TriangleStrip : GL_TRIANGLE_STRIP;
        }
    }
}

/**
 * Managed upload, removing, and drawing static draw commands.
 */
private class StaticBufferManager
{
    final forceIncludeGL : GLSyncWrapper;

    /**
     * Constant identity matrix.
     * 
     * Used by `BufferDrawCommand` as the lone model matrix as `BufferDrawCommand` currently does not provide a model matrix.
     */
    final identityMatrix : Matrix;

    /**
     * The maximum number of vertices which can fix in the buffer.
     */
    final maxVertices : Int;

    /**
     * The maximum number of indices which can fix in the buffer.
     */
    final maxIndices : Int;

    /**
     * OpenGL buffer ID of the static buffer.
     */
    final glVbo : Int;

    /**
     * OpenGL buffer ID of the index buffer.
     */
    final glIbo : Int;

    /**
     * All of the uploaded ranges, keyed by their command ID.
     */
    final ranges : Map<Int, StaticBufferRange>;

    /**
     * Ranges to be removed to make space for a new range.
     */
    final rangesToRemove : Array<Int>;

    /**
     * Current vertex write position for uploading new commands.
     */
    var vtxPosition : Int;

    /**
     * Current index write position for uploading new commands.
     */
    var idxPosition : Int;

    public function new(_vtxBufferSize : Int, _idxBufferSize : Int, _glVbo : Int, _glIbo : Int)
    {
        forceIncludeGL = new GLSyncWrapper();
        identityMatrix = new Matrix();
        maxVertices    = _vtxBufferSize;
        maxIndices     = _idxBufferSize;
        glVbo          = _glVbo;
        glIbo          = _glIbo;
        ranges         = [];
        rangesToRemove = [];
        vtxPosition    = 0;
        idxPosition    = 0;
    }

    /**
     * Upload a geometry draw command to the static buffer.
     * Will remove other ranges to make space.
     * @param _command Command to upload.
     */
    public function uploadGeometry(_command : GeometryDrawCommand)
    {
        if (_command.vertices > maxVertices || _command.indices > maxIndices)
        {
            throw 'command ${_command.id} too large to fit in static buffer';
        }

        if (_command.vertices > (maxVertices - vtxPosition) || _command.indices > (maxIndices - idxPosition))
        {
            rangesToRemove.resize(0);

            for (key => range in ranges)
            {
                if ((0 < (range.vtxPosition + range.vtxLength) && (0 + _command.vertices) > 0) || (0 < (range.idxPosition + range.idxLength) && (0 + _command.indices) > 0))
                {
                    rangesToRemove.push(key);
                }

                glDeleteBuffers(2, [ range.glCommandBuffer, range.glMatrixBuffer ]);
            }

            for (id in rangesToRemove)
            {
                ranges.remove(id);
            }
        }

        if (!ranges.exists(_command.id))
        {
            var vtxPtr = new Float32Array(_command.vertices * 9);
            var idxPtr = new UInt16Array(_command.indices);
            var vtxIdx = 0;
            var idxIdx = 0;

            for (geom in _command.geometry)
            {
                for (index in geom.indices)
                {
                    idxPtr[idxIdx++] = index;
                }

                for (vertex in geom.vertices)
                {
                    vtxPtr[vtxIdx++] = vertex.position.x;
                    vtxPtr[vtxIdx++] = vertex.position.y;
                    vtxPtr[vtxIdx++] = vertex.position.z;
                    vtxPtr[vtxIdx++] = vertex.color.r;
                    vtxPtr[vtxIdx++] = vertex.color.g;
                    vtxPtr[vtxIdx++] = vertex.color.b;
                    vtxPtr[vtxIdx++] = vertex.color.a;
                    vtxPtr[vtxIdx++] = vertex.texCoord.x;
                    vtxPtr[vtxIdx++] = vertex.texCoord.y;
                }
            }

            glNamedBufferSubData(glVbo, vtxPosition * 9 * 4, vtxPtr.view.buffer.length, vtxPtr.view.buffer.getData());
            glNamedBufferSubData(glIbo, idxPosition * 2, idxPtr.view.buffer.length, idxPtr.view.buffer.getData());

            // TODO : Create a matrix and command buffer for the draw command.
            var buffers = [ 0, 0 ];
            glCreateBuffers(buffers.length, buffers);

            // Create command buffer
            if (_command.indices > 0)
            {
                var mdiCommands  = new UInt32Array(_command.geometry.length * 5);
                var writePos     = 0;
                var cmdVtxOffset = vtxPosition;
                var cmdIdxOffset = idxPosition;

                for (geom in _command.geometry)
                {
                    mdiCommands[writePos++] = geom.indices.length;
                    mdiCommands[writePos++] = 1;
                    mdiCommands[writePos++] = cmdIdxOffset;
                    mdiCommands[writePos++] = cmdVtxOffset;
                    mdiCommands[writePos++] = 0;

                    cmdVtxOffset += geom.vertices.length;
                }

                glNamedBufferStorage(buffers[0], _command.geometry.length * 20, mdiCommands.view.buffer.getData(), 0);
            }
            else
            {
                var mdiCommands  = new UInt32Array(_command.geometry.length * 4);
                var writePos     = 0;
                var cmdVtxOffset = 0;

                for (geom in _command.geometry)
                {
                    mdiCommands[writePos++] = geom.vertices.length;
                    mdiCommands[writePos++] = 1;
                    mdiCommands[writePos++] = cmdVtxOffset;
                    mdiCommands[writePos++] = 0;

                    cmdVtxOffset += geom.vertices.length;
                }

                glNamedBufferStorage(buffers[0], _command.geometry.length * 16, mdiCommands.view.buffer.getData(), 0);
            }

            // Create matrix buffer
            var matrixBuffer = new Float32Array(32 + (_command.geometry.length * 16));
            glNamedBufferStorage(buffers[1], matrixBuffer.view.buffer.length, matrixBuffer.view.buffer.getData(), GL_DYNAMIC_STORAGE_BIT);

            // TODO : Add a new range entry to the map.
            ranges.set(_command.id, new StaticBufferRange(buffers[0], buffers[1], matrixBuffer, vtxPosition, idxPosition, _command.vertices, _command.indices, _command.geometry.length));

            vtxPosition += _command.vertices;
            idxPosition += _command.indices;
        }

        // Upload the model matrices for all geometry in the command.

        var rng = inline get(_command);
        var ptr = Pointer.arrayElem(rng.matrixBuffer.view.buffer.getData(), 64);
        for (geom in _command.geometry)
        {
            Stdlib.memcpy(ptr.incBy(64), (geom.transformation.transformation : Float32Array).view.buffer.getData().address(0), 64);
        }
    }

    /**
     * Upload a buffer draw command to the static buffer.
     * Will remove other ranges to make space.
     * @param _command Command to upload.
     */
    public function uploadBuffer(_command : BufferDrawCommand)
    {
        if (_command.vertices > maxVertices || _command.indices > maxIndices)
        {
            throw 'command ${_command.id} too large to fit in static buffer';
        }

        if (_command.vertices > (maxVertices - vtxPosition) || _command.indices > (maxIndices - idxPosition))
        {
            rangesToRemove.resize(0);

            for (key => range in ranges)
            {
                if ((0 < (range.vtxPosition + range.vtxLength) && (0 + _command.vertices) > 0) || (0 < (range.idxPosition + range.idxLength) && (0 + _command.indices) > 0))
                {
                    rangesToRemove.push(key);

                    trace('removing $key');
                }

                glDeleteBuffers(2, [ range.glCommandBuffer, range.glMatrixBuffer ]);
            }

            for (id in rangesToRemove)
            {
                ranges.remove(id);
            }
        }

        if (!ranges.exists(_command.id))
        {
            var vtxRange = _command.vtxData.subarray(_command.vtxStartIndex, _command.vtxEndIndex);
            var idxRange = _command.idxData.subarray(_command.idxStartIndex, _command.idxEndIndex);
            glNamedBufferSubData(glVbo, vtxPosition * 9 * 4, vtxRange.length * 4, vtxRange.view.buffer.getData());
            glNamedBufferSubData(glIbo, idxPosition * 2    , idxRange.length * 2, idxRange.view.buffer.getData());

            // TODO : Create a matrix and command buffer for the draw command.
            var buffers = [ 0, 0 ];
            glCreateBuffers(buffers.length, buffers);

            // Create command buffer
            if (_command.indices > 0)
            {
                var mdiCommands  = new UInt32Array(5);
                var writePos     = 0;
                var cmdVtxOffset = vtxPosition;
                var cmdIdxOffset = idxPosition;

                mdiCommands[writePos++] = _command.indices;
                mdiCommands[writePos++] = 1;
                mdiCommands[writePos++] = cmdIdxOffset;
                mdiCommands[writePos++] = cmdVtxOffset;
                mdiCommands[writePos++] = 0;

                glNamedBufferStorage(buffers[0], 20, mdiCommands.view.buffer.getData(), 0);
            }
            else
            {
                var mdiCommands  = new UInt32Array(4);
                var writePos     = 0;
                var cmdVtxOffset = 0;

                mdiCommands[writePos++] = _command.vertices;
                mdiCommands[writePos++] = 1;
                mdiCommands[writePos++] = cmdVtxOffset;
                mdiCommands[writePos++] = 0;

                glNamedBufferStorage(buffers[0], 16, mdiCommands.view.buffer.getData(), 0);
            }

            // Create matrix buffer
            var matrixBuffer = new Float32Array(48);
            Stdlib.memcpy(matrixBuffer.view.buffer.getData().address(128), (identityMatrix : Float32Array).view.buffer.getData().address(0), 64);
            glNamedBufferStorage(buffers[1], matrixBuffer.view.buffer.length, matrixBuffer.view.buffer.getData(), GL_DYNAMIC_STORAGE_BIT);

            // TODO : Add a new range entry to the map.
            ranges.set(_command.id, new StaticBufferRange(buffers[0], buffers[1], matrixBuffer, vtxPosition, idxPosition, _command.vertices, _command.indices, 1));

            vtxPosition += _command.vertices;
            idxPosition += _command.indices;
        }
    }

    /**
     * Draw an uploaded draw command.
     * @param _command Command to draw.
     */
    public function draw(_command : DrawCommand)
    {
        if (_command.indices > 0)
        {
            untyped __cpp__('glMultiDrawElementsIndirect({0}, GL_UNSIGNED_SHORT, 0, {1}, 0)', getPrimitiveType(_command.primitive), get(_command).drawCount);
        }
        else
        {
            untyped __cpp__('glMultiDrawArraysIndirect({0}, 0, {1}, 0)', getPrimitiveType(_command.primitive), get(_command).drawCount);
        }
    }

    /**
     * Get information about an uploaded range.
     * @param _command Uploaded command to get info on.
     * @return StaticBufferRange
     */
    public function get(_command : DrawCommand) : StaticBufferRange
    {
        return ranges.get(_command.id).sure();
    }

    /**
     * Returns an OpenGL primitive constant from a flurry primitive enum.
     * @param _primitive Primitive type.
     * @return Int
     */
    function getPrimitiveType(_primitive : PrimitiveType) : Int
    {
        return switch (_primitive)
        {
            case Points        : GL_POINTS;
            case Lines         : GL_LINES;
            case LineStrip     : GL_LINE_STRIP;
            case Triangles     : GL_TRIANGLES;
            case TriangleStrip : GL_TRIANGLE_STRIP;
        }
    }
}

/**
 * Represents an uploaded `DrawCommand` in the static buffer.
 */
private class StaticBufferRange
{
    /**
     * OpenGL buffer ID for the buffer to be bound to `GL_DRAW_INDIRECT_BUFFER` to provide draw commands.
     */
    public final glCommandBuffer : Int;

    /**
     * OpenGL buffer ID for the buffer to be bound to the default matrix ssbo.
     */
    public final glMatrixBuffer : Int;
    
    /**
     * Bytes to store matrices to be uploaded to the GPU.
     * 
     * Enough space for a projection, view, and `drawCount` model matrices.
     */
    public final matrixBuffer : Float32Array;

    /**
     * The vertex offset into the vertex buffer this draw command is found.
     */
    public final vtxPosition : Int;

    /**
     * The index offfset into the index buffer this draw command is found.
     */
    public final idxPosition : Int;

    /**
     * The number of vertices in this draw command.
     */
    public final vtxLength : Int;

    /**
     * The number of indices in this draw command.
     */
    public final idxLength : Int;

    /**
     * The number of draw calls to make for this draw command. Used for multi draw indirect functions.
     * 
     * Always 1 for `BufferDrawCommand`. Equal to the number of geometries for `GeometryDrawCommand`.
     */
    public final drawCount : Int;

    public function new(_glCommandBuffer : Int, _glMatrixBuffer : Int, _matrixBuffer : Float32Array, _vtxPosition : Int, _idxPosition : Int, _vtxLength : Int, _idxLength : Int, _drawCount : Int)
    {
        glCommandBuffer = _glCommandBuffer;
        glMatrixBuffer  = _glMatrixBuffer;
        matrixBuffer    = _matrixBuffer;
        vtxPosition     = _vtxPosition;
        idxPosition     = _idxPosition;
        vtxLength       = _vtxLength;
        idxLength       = _idxLength;
        drawCount       = _drawCount;
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
        sync = null;
    }
}
