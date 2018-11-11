package uk.aidanlee.flurry.api.gpu.backend;

import sdl.Window;
import sdl.GLContext;
import sdl.SDL;
import haxe.ds.Map;
import snow.modules.opengl.GL;
import snow.api.buffers.Uint8Array;
import snow.api.buffers.Float32Array;
import snow.api.buffers.Uint16Array;
import uk.aidanlee.flurry.api.gpu.Renderer.RendererOptions;
import uk.aidanlee.flurry.api.gpu.backend.IRendererBackend.ShaderType;
import uk.aidanlee.flurry.api.gpu.backend.IRendererBackend.ShaderLayout;
import uk.aidanlee.flurry.api.gpu.batcher.DrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.BufferDrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.GeometryDrawCommand;
import uk.aidanlee.flurry.api.gpu.geometry.Blending.BlendMode;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.ResourceEvents;

/**
 * WebGL backend written against the webGL 1.0 spec (openGL ES 2.0).
 * Uses snows openGL module so it can run on desktops and web platforms.
 * Allows targeting web, osx, and older integrated GPUs (anywhere where openGL 4.5 isn't supported).
 */
class WebGLBackend implements IRendererBackend
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
     * Event bus for the rendering backend to listen to resource creation events.
     */
    final events : EventBus;

    /**
     * Access to the renderer who owns this backend.
     */
    final rendererStats : RendererStats;

    /**
     * The single VBO used by the backend.
     */
    final glVbo : GLBuffer;

    /**
     * The single index buffer used by the backend.
     */
    final glIbo : GLBuffer;

    /**
     * Vertex buffer used by this backend.
     */
    final vertexBuffer : Float32Array;

    /**
     * Index buffer used by this backend.
     */
    final indexBuffer : Uint16Array;

    /**
     * Backbuffer display, default target if none is specified.
     */
    final backbuffer : BackBuffer;

    /**
     * Transformation vector used for transforming geometry vertices by a matrix.
     */
    final transformationVector : Vector;

    /**
     * Tracks the position and number of vertices for draw commands uploaded into the dynamic buffer.
     */
    final dynamicCommandRanges : Map<Int, DrawCommandRange>;

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
     * Framebuffer objects keyed by their associated image resource IDs.
     * Framebuffers will only be generated when an image resource is used as a target.
     * Will be destroyed when the associated image resource is destroyed.
     */
    final framebufferObjects : Map<String, Int>;

    /**
     * The number of vertices that have been written into the vertex buffer this frame.
     */
    var vertexOffset : Int;

    /**
     * The number of 32bit floats that have been written into the vertex buffer this frame.
     */
    var vertexFloatOffset : Int;

    /**
     * The number of bytes that have been written into the vertex buffer this frame.
     */
    var vertexByteOffset : Int;

    /**
     * The number of indices that have been written into the index buffer this frame.
     */
    var indexOffset : Int;

    /**
     * The number of bytes that have been written into the index buffer this frame.
     */
    var indexByteOffset : Int;

    // GL state variables

    var target   : ImageResource;
    var shader   : ShaderResource;
    var clip     : Rectangle;
    var viewport : Rectangle;
    var boundTextures : Array<Int>;

    // Event listener IDs

    final evResourceCreated : Int;

    final evResourceRemoved : Int;

    // SDL Window and GL Context

    var window : Window;

    var glContext : GLContext;

    public function new(_events : EventBus, _rendererStats : RendererStats, _options : RendererOptions)
    {
        events        = _events;
        rendererStats = _rendererStats;

        createWindow(_options);

        shaderPrograms = new Map();
        shaderUniforms = new Map();
        textureObjects = new Map();
        framebufferObjects = new Map();

        transformationVector = new Vector();
        dynamicCommandRanges = new Map();

        vertexOffset      = 0;
        vertexFloatOffset = 0;
        vertexByteOffset  = 0;

        indexOffset     = 0;
        indexByteOffset = 0;

        // Create and bind a singular VBO.
        // Only needs to be bound once since it is used for all drawing.
        vertexBuffer = new Float32Array((_options.maxDynamicVertices + _options.maxUnchangingVertices) * VERTEX_FLOAT_SIZE);
        indexBuffer  = new Uint16Array(_options.maxDynamicIndices + _options.maxUnchangingIndices);

        #if cpp

        // Core OpenGL profiles require atleast one VAO is bound.
        // So if we're running on a native platform create and bind a VAO

        var vao = [ 0 ];
        opengl.GL.glGenVertexArrays(1, vao);
        opengl.GL.glBindVertexArray(vao[0]);

        #end

        glVbo = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, glVbo);
        GL.bufferData(GL.ARRAY_BUFFER, vertexBuffer, GL.DYNAMIC_DRAW);

        glIbo = GL.createBuffer();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, glIbo);
        GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBuffer, GL.DYNAMIC_DRAW);

        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);
        GL.enableVertexAttribArray(2);
        GL.vertexAttribPointer(0, 3, GL.FLOAT, false, VERTEX_FLOAT_SIZE * Float32Array.BYTES_PER_ELEMENT, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_POS);
        GL.vertexAttribPointer(1, 4, GL.FLOAT, false, VERTEX_FLOAT_SIZE * Float32Array.BYTES_PER_ELEMENT, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_COL);
        GL.vertexAttribPointer(2, 2, GL.FLOAT, false, VERTEX_FLOAT_SIZE * Float32Array.BYTES_PER_ELEMENT, Float32Array.BYTES_PER_ELEMENT * VERTEX_OFFSET_TEX);

        // Create a representation of the backbuffer.
        backbuffer = new BackBuffer(_options.width, _options.height, _options.dpi, GL.getParameter(GL.FRAMEBUFFER));

        // Default blend mode
        // TODO : Move this to be a settable property in the geometry or renderer or something
        GL.blendEquationSeparate(GL.FUNC_ADD, GL.FUNC_ADD);
        GL.blendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ZERO);

        // Set the clear colour
        GL.clearColor(0.2, 0.2, 0.2, 1.0);

        // Default scissor test
        GL.enable(GL.SCISSOR_TEST);
        GL.scissor(0, 0, backbuffer.width, backbuffer.height);

        // default state
        viewport = new Rectangle(0, 0, backbuffer.width, backbuffer.height);
        clip     = new Rectangle(0, 0, backbuffer.width, backbuffer.height);
        shader   = null;
        target   = null;
        boundTextures = [];

        // Listen to resource creation events.
        evResourceCreated = events.listen(ResourceEvents.Created, onResourceCreated);
        evResourceRemoved = events.listen(ResourceEvents.Removed, onResourceRemoved);
    }

    /**
     * Clear the render target.
     */
    public function clear()
    {
        // Disable the clip to clear the entire target.
        clip.set(0, 0, backbuffer.width, backbuffer.height);
        GL.scissor(0, 0, backbuffer.width, backbuffer.height);

        GL.clear(GL.COLOR_BUFFER_BIT);
    }

    public function clearUnchanging()
    {
        //
    }

    public function preDraw()
    {
        vertexOffset      = 0;
        vertexFloatOffset = 0;
        vertexByteOffset  = 0;

        indexOffset     = 0;
        indexByteOffset = 0;
    }

    /**
     * Upload geometries to the gpu VRAM.
     * @param _commands Array of commands to upload.
     */
    public function uploadGeometryCommands(_commands : Array<GeometryDrawCommand>) : Void
    {
        var startVertexByteOffset  = vertexByteOffset;
        var startVertexFloatOffset = vertexFloatOffset;

        var startIndexOffset     = indexOffset;
        var startIndexByteOffset = indexByteOffset;

        for (command in _commands)
        {
            dynamicCommandRanges.set(command.id, new DrawCommandRange(command.vertices, vertexOffset, command.indices, indexByteOffset));

            for (geom in command.geometry)
            {
                var matrix = geom.transformation.transformation;

                for (index in geom.indices)
                {
                    indexBuffer[indexOffset++] = vertexOffset + index;
                    indexByteOffset += Uint16Array.BYTES_PER_ELEMENT;
                }

                for (vertex in geom.vertices)
                {
                    // Copy the vertex into another vertex.
                    // This allows us to apply the transformation without permanently modifying the original geometry.
                    transformationVector.copyFrom(vertex.position);
                    transformationVector.transform(matrix);

                    vertexBuffer[vertexFloatOffset++] = transformationVector.x;
                    vertexBuffer[vertexFloatOffset++] = transformationVector.y;
                    vertexBuffer[vertexFloatOffset++] = transformationVector.z;
                    vertexBuffer[vertexFloatOffset++] = vertex.color.r;
                    vertexBuffer[vertexFloatOffset++] = vertex.color.g;
                    vertexBuffer[vertexFloatOffset++] = vertex.color.b;
                    vertexBuffer[vertexFloatOffset++] = vertex.color.a;
                    vertexBuffer[vertexFloatOffset++] = vertex.texCoord.x;
                    vertexBuffer[vertexFloatOffset++] = vertex.texCoord.y;

                    vertexOffset++;
                    vertexByteOffset += (VERTEX_FLOAT_SIZE * Float32Array.BYTES_PER_ELEMENT);
                }
            }
        }

        GL.bufferSubData(GL.ARRAY_BUFFER        , startVertexByteOffset, vertexBuffer.subarray(startVertexFloatOffset, vertexFloatOffset));
        GL.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndexByteOffset , indexBuffer.subarray(startIndexOffset, indexOffset));
    }

    /**
     * Upload buffer data to the gpu VRAM.
     * @param _commands Array of commands to upload.
     */
    public function uploadBufferCommands(_commands : Array<BufferDrawCommand>) : Void
    {
        for (command in _commands)
        {
            dynamicCommandRanges.set(command.id, new DrawCommandRange(command.vertices, vertexOffset, 0, 0));

            GL.bufferSubData(GL.ARRAY_BUFFER, vertexByteOffset, command.buffer.subarray(command.startIndex, command.endIndex));

            vertexOffset      += command.vertices;
            vertexFloatOffset += command.vertices * VERTEX_FLOAT_SIZE;
            vertexByteOffset  += command.vertices * VERTEX_FLOAT_SIZE * Float32Array.BYTES_PER_ELEMENT;
        }
    }

    /**
     * Draw an array of commands. Command data must be uploaded to the GPU before being used.
     * @param _commands    Commands to draw.
     * @param _recordStats Record stats for this submit.
     */
    public function submitCommands(_commands : Array<DrawCommand>, _recordStats : Bool = true) : Void
    {
        for (command in _commands)
        {
            var range = dynamicCommandRanges.get(command.id);

            // Change the state so the vertices are drawn correctly.
            setState(command, !_recordStats);

            // Draw the actual vertices
            if (range.indices > 0)
            {
                switch (command.primitive)
                {
                    case Points        : GL.drawElements(GL.POINTS        , range.indices, GL.UNSIGNED_SHORT, range.indexOffset);
                    case Lines         : GL.drawElements(GL.LINES         , range.indices, GL.UNSIGNED_SHORT, range.indexOffset);
                    case LineStrip     : GL.drawElements(GL.LINE_STRIP    , range.indices, GL.UNSIGNED_SHORT, range.indexOffset);
                    case Triangles     : GL.drawElements(GL.TRIANGLES     , range.indices, GL.UNSIGNED_SHORT, range.indexOffset);
                    case TriangleStrip : GL.drawElements(GL.TRIANGLE_STRIP, range.indices, GL.UNSIGNED_SHORT, range.indexOffset);
                }
            }
            else
            {
                switch (command.primitive)
                {
                    case Points        : GL.drawArrays(GL.POINTS        , range.vertexOffset, range.vertices);
                    case Lines         : GL.drawArrays(GL.LINES         , range.vertexOffset, range.vertices);
                    case LineStrip     : GL.drawArrays(GL.LINE_STRIP    , range.vertexOffset, range.vertices);
                    case Triangles     : GL.drawArrays(GL.TRIANGLES     , range.vertexOffset, range.vertices);
                    case TriangleStrip : GL.drawArrays(GL.TRIANGLE_STRIP, range.vertexOffset, range.vertices);
                }
            }            

            // Record stats about this draw call.
            if (_recordStats)
            {
                rendererStats.dynamicDraws++;
                rendererStats.totalVertices += range.vertices;
            }
        }
    }

    public function postDraw()
    {
        SDL.GL_SwapWindow(window);
    }

    /**
     * Called when the game window is resized.
     * @param _width  new width of the window.
     * @param _height new height of the window.
     */
    public function resize(_width : Int, _height : Int)
    {
        backbuffer.width  = _width;
        backbuffer.height = _height;
    }

    /**
     * Unmap the buffer and iterate over all resources deleting their resources and remove them from the structure.
     */
    public function cleanup()
    {
        for (shaderID in shaderPrograms.keys())
        {
            GL.deleteProgram(shaderPrograms.get(shaderID));

            shaderPrograms.remove(shaderID);
            shaderUniforms.remove(shaderID);
        }

        for (textureID in textureObjects.keys())
        {
            GL.deleteTexture(textureObjects.get(textureID));
            textureObjects.remove(textureID);

            if (framebufferObjects.exists(textureID))
            {
                GL.deleteFramebuffer(framebufferObjects.get(textureID));
                framebufferObjects.remove(textureID);
            }
        }

        SDL.GL_DeleteContext(glContext);
        SDL.destroyWindow(window);
    }

    // #region SDL Window Management

    function createWindow(_options : RendererOptions)
    {        
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
        SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

        window    = SDL.createWindow('Flurry', SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, _options.width, _options.height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
        glContext = SDL.GL_CreateContext(window);

        SDL.GL_MakeCurrent(window, glContext);

        // TODO : Error handling if GLEW doesn't return OK.
        glew.GLEW.init();
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
     * Creates a shader from a vertex and fragment source.
     * @param _vert   Vertex shader source.
     * @param _frag   Fragment shader source.
     * @param _layout Shader layout JSON description.
     * @return Shader
     */
    function createShader(_resource : ShaderResource)
    {
        if (_resource.webgl == null)
        {
            throw 'WebGL Backend Exception : ${_resource.id} : Attempting to create a shader from a resource which has no webgl shader source';
        }

        if (shaderPrograms.exists(_resource.id))
        {
            throw 'WebGL Backend Exception : ${_resource.id} : Attempting to create a shader which already exists';
        }

        // Create vertex shader.
        var vertex = GL.createShader(GL.VERTEX_SHADER);
        GL.shaderSource(vertex, _resource.webgl.vertex);
        GL.compileShader(vertex);

        if (GL.getShaderParameter(vertex, GL.COMPILE_STATUS) == 0)
        {
            throw 'WebGL Backend Exception : ${_resource.id} : Error compiling vertex shader : ${GL.getShaderInfoLog(vertex)}';
        }

        // Create fragment shader.
        var fragment = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(fragment, _resource.webgl.fragment);
        GL.compileShader(fragment);

        if (GL.getShaderParameter(fragment, GL.COMPILE_STATUS) == 0)
        {
            throw 'WebGL Backend Exception : ${_resource.id} : Error compiling fragment shader : ${GL.getShaderInfoLog(fragment)}';
        }

        // Link the shaders into a program.
        var program = GL.createProgram();
        GL.attachShader(program, vertex);
        GL.attachShader(program, fragment);
        GL.linkProgram(program);

        if (GL.getProgramParameter(program, GL.LINK_STATUS) == 0)
        {
            throw 'WebGL Backend Exception : ${_resource.id} : Error linking program : ${GL.getProgramInfoLog(program)}';
        }

        // Delete the shaders now that they're linked
        GL.deleteShader(vertex);
        GL.deleteShader(fragment);

        // WebGL has no uniform blocks so all inner values are converted to uniforms
        var textureLocations = [];
        var uniformLocations = [ GL.getUniformLocation(program, 'projection'), GL.getUniformLocation(program, 'view') ];
        for (texture in _resource.layout.textures)
        {
            textureLocations.push(GL.getUniformLocation(program, texture));
        }
        for (block in _resource.layout.blocks)
        {
            for (uniform in block.vals)
            {
                uniformLocations.push(GL.getUniformLocation(program, uniform.name));
            }
        }

        shaderPrograms.set(_resource.id, program);
        shaderUniforms.set(_resource.id, new ShaderLocations(_resource.layout, textureLocations, uniformLocations));
    }

    /**
     * Removes and frees the resources used by a shader.
     * @param _name Name of the shader.
     */
    function removeShader(_resource : ShaderResource)
    {
        GL.deleteProgram(shaderPrograms.get(_resource.id));

        shaderPrograms.remove(_resource.id);
        shaderUniforms.remove(_resource.id);
    }

    /**
     * Creates a new texture given an array of pixel data.
     * @param _name   Name of the texture/
     * @param _pixels Pixel data.
     * @param _width  Width of the texture.
     * @param _height Height of the texture.
     * @return Texture
     */
    function createTexture(_resource : ImageResource)
    {
        var id = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, id);

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, _resource.width, _resource.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, Uint8Array.fromArray(_resource.pixels));

        GL.bindTexture(GL.TEXTURE_2D, 0);

        textureObjects.set(_resource.id, id);
    }

    /**
     * Removes and frees the resources used by a texture.
     * @param _name Name of the texture.
     */
    function removeTexture(_resource : ImageResource)
    {
        GL.deleteTexture(textureObjects.get(_resource.id));
        textureObjects.remove(_resource.id);
    }

    //  #endregion

    /**
     * Update the openGL state so it can draw the provided command.
     * @param _command      Command to set the state for.
     * @param _disableStats If stats are to be recorded.
     */
    function setState(_command : DrawCommand, _disableStats : Bool)
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
            GL.viewport(Std.int(x), Std.int(y), Std.int(w), Std.int(h));

            if (!_disableStats)
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
            GL.scissor(Std.int(x), Std.int(y), Std.int(w), Std.int(h));

            if (!_disableStats)
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
                var fbo = GL.createFramebuffer();
                GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
                GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, textureObjects.get(target.id), 0);

                if (GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)
                {
                    throw 'WebGL Backend Exception : ${target.id} : Framebuffer not complete';
                }

                framebufferObjects.set(target.id, fbo);

                GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
            }

            GL.bindFramebuffer(GL.FRAMEBUFFER, target != null ? framebufferObjects.get(target.id) : backbuffer.framebufferObject);

            if (!_disableStats)
            {
                rendererStats.targetSwaps++;
            }
        }

        // Apply shader changes.
        if (shader != _command.shader)
        {
            shader = _command.shader;
            GL.useProgram(shaderPrograms.get(shader.id));

            if (!_disableStats)
            {
                rendererStats.shaderSwaps++;
            }
        }
        
        // Apply the shaders uniforms
        // TODO : Only set uniforms if the value has changed.
        setUniforms(_command, _disableStats);

        // Set the blending
        if (_command.blending)
        {
            GL.enable(GL.BLEND);
            GL.blendFuncSeparate(getBlendMode(_command.srcRGB), getBlendMode(_command.dstRGB), getBlendMode(_command.srcAlpha), getBlendMode(_command.dstAlpha));

            if (!_disableStats)
            {
                rendererStats.blendSwaps++;
            }
        }
        else
        {
            GL.disable(GL.BLEND);

            if (!_disableStats)
            {
                rendererStats.blendSwaps++;
            }
        }
    }

    /**
     * Apply all of a shaders uniforms.
     * @param _combined     Only required uniform. VP combined matrix.
     * @param _disableStats If stats are to be recorded.
     */
    function setUniforms(_command : DrawCommand, _disableStats : Bool)
    {
        // Find this shaders location cache.
        var cache = shaderUniforms.get(_command.shader.id);

        // TEMP : Set all textures all the time.
        // TODO : Store all bound texture IDs and check before binding textures.
        if (cache.layout.textures.length > _command.textures.length)
        {
            throw 'Error : More textures required by the shader than are provided by the draw command';
        }
        else
        {
            // First resize the bound texture arrays to the draw commands texture ammount
            if (boundTextures.length != _command.textures.length)
            {
                boundTextures.resize(_command.textures.length);
            }

            // then go through each texture and bind it if it isn't already.
            for (i in 0...boundTextures.length)
            {
                var glTextureID  = textureObjects.get(_command.textures[i].id);
                if (glTextureID != boundTextures[i])
                {
                    GL.activeTexture(GL.TEXTURE0 + i);
                    GL.bindTexture(GL.TEXTURE_2D, textureObjects.get(_command.textures[i].id));

                    GL.uniform1i(cache.textureLocations[i], i);

                    boundTextures[i] = glTextureID;

                    if (!_disableStats)
                    {
                        rendererStats.textureSwaps++;
                    }
                }
            }
        }

        // Write the default matrix uniforms
        GL.uniformMatrix4fv(cache.uniformLocations[0], false, _command.projection);
        GL.uniformMatrix4fv(cache.uniformLocations[1], false, _command.view);

        // Start at uniform index 2 since the first two are the default matrix uniforms.
        var uniformIdx = 2;
        for (i in 0...cache.layout.blocks.length)
        {
            for (val in cache.layout.blocks[i].vals)
            {
                switch (ShaderType.createByName(val.type)) {
                    case Matrix4: GL.uniformMatrix4fv(cache.uniformLocations[uniformIdx++], false, _command.shader.uniforms.matrix4.get(val.name));
                    case Vector4: GL.uniform4fv(cache.uniformLocations[uniformIdx++], vectorToFloatArray(_command.shader.uniforms.vector4.get(val.name)));
                    case Int    : GL.uniform1f(cache.uniformLocations[uniformIdx++], _command.shader.uniforms.int.get(val.name));
                }
            }
        }
    }

    function vectorToFloatArray(_vector : Vector) : Float32Array
    {
        var array = new Float32Array(4);
        array[0] = _vector.x;
        array[1] = _vector.y;
        array[2] = _vector.z;
        array[3] = _vector.w;

        return array;
    }

    function getBlendMode(_mode : BlendMode) : Int
    {
        return switch (_mode)
        {
            case Zero             : GL.ZERO;
            case One              : GL.ONE;
            case SrcAlphaSaturate : GL.SRC_ALPHA_SATURATE;
            case SrcColor         : GL.SRC_COLOR;
            case OneMinusSrcColor : GL.ONE_MINUS_SRC_COLOR;
            case SrcAlpha         : GL.SRC_ALPHA;
            case OneMinusSrcAlpha : GL.ONE_MINUS_SRC_ALPHA;
            case DstAlpha         : GL.DST_ALPHA;
            case OneMinusDstAlpha : GL.ONE_MINUS_DST_ALPHA;
            case DstColor         : GL.DST_COLOR;
            case OneMinusDstColor : GL.ONE_MINUS_DST_COLOR;
            case _: 0;
        }
    }
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
    public final textureLocations : Array<GLUniformLocation>;

    /**
     * Location of all non texture uniforms.
     */
    public final uniformLocations : Array<GLUniformLocation>;

    public function new(_layout : ShaderLayout, _textureLocations : Array<GLUniformLocation>, _uniformLocations : Array<GLUniformLocation>)
    {
        layout           = _layout;
        textureLocations = _textureLocations;
        uniformLocations = _uniformLocations;
    }
}

/**
 * Stores the range of a draw command.
 */
private class DrawCommandRange
{
    /**
     * The number of vertices in this draw command.
     */
    public final vertices : Int;

    /**
     * The number of vertices this command is offset into the current range.
     */
    public final vertexOffset : Int;

    /**
     * The number of indices in this draw command.
     */
    public final indices : Int;

    /**
     * The number of bytes this command is offset into the current range.
     */
    public final indexOffset : Int;

    inline public function new(_vertices : Int, _vertexOffset : Int, _indices : Int, _indexOffset)
    {
        vertices     = _vertices;
        vertexOffset = _vertexOffset;
        indices      = _indices;
        indexOffset  = _indexOffset;
    }
}
