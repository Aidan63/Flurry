package uk.aidanlee.flurry.modules.imgui;

import cpp.Pointer;
import cpp.RawPointer;
import haxe.io.Float32Array;
import haxe.io.UInt16Array;
import uk.aidanlee.flurry.api.input.Keycodes;
import uk.aidanlee.flurry.api.input.Scancodes;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Hash;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.gpu.UploadType;
import uk.aidanlee.flurry.api.gpu.camera.OrthographicCamera;
import uk.aidanlee.flurry.api.gpu.batcher.BufferDrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher.DepthOptions;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher.StencilOptions;
import imgui.ImGui;
import imgui.draw.ImDrawData;
import imgui.util.ImVec2;
import imgui.util.ImVec4;

class ImGuiImpl
{
    final flurry   : Flurry;
    final texture  : ImageResource;
    final vtxData  : Float32Array;
    final idxData  : UInt16Array;
    final camera   : OrthographicCamera;
    final depth    : DepthOptions;
    final stencil  : StencilOptions;

    public function new(_flurry : Flurry)
    {
        flurry = _flurry;
        camera = new OrthographicCamera(flurry.display.width, flurry.display.height);
        depth  = {
            depthTesting  : false,
            depthMasking  : false,
            depthFunction : Always
        };
        stencil = {
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
        }

        ImGui.createContext();

        var io = ImGui.getIO();
        io.configFlags = ImGuiConfigFlags.NavEnableKeyboard;
        io.keyMap[ImGuiKey.Tab       ] = Scancodes.tab;
        io.keyMap[ImGuiKey.LeftArrow ] = Scancodes.left;
        io.keyMap[ImGuiKey.RightArrow] = Scancodes.right;
        io.keyMap[ImGuiKey.UpArrow   ] = Scancodes.up;
        io.keyMap[ImGuiKey.DownArrow ] = Scancodes.down;
        io.keyMap[ImGuiKey.PageUp    ] = Scancodes.pageup;
        io.keyMap[ImGuiKey.PageDown  ] = Scancodes.pagedown;
        io.keyMap[ImGuiKey.Home      ] = Scancodes.home;
        io.keyMap[ImGuiKey.End       ] = Scancodes.end;
        io.keyMap[ImGuiKey.Delete    ] = Scancodes.delete;
        io.keyMap[ImGuiKey.Backspace ] = Scancodes.backspace;
        io.keyMap[ImGuiKey.Insert    ] = Scancodes.insert;
        io.keyMap[ImGuiKey.Space     ] = Scancodes.space;
        io.keyMap[ImGuiKey.Enter     ] = Scancodes.enter;
        io.keyMap[ImGuiKey.Escape    ] = Scancodes.escape;
        io.keyMap[ImGuiKey.A         ] = Scancodes.key_a;
        io.keyMap[ImGuiKey.C         ] = Scancodes.key_c;
        io.keyMap[ImGuiKey.V         ] = Scancodes.key_v;
        io.keyMap[ImGuiKey.X         ] = Scancodes.key_x;
        io.keyMap[ImGuiKey.Y         ] = Scancodes.key_y;
        io.keyMap[ImGuiKey.Z         ] = Scancodes.key_z;
        io.setClipboardTextFn = cpp.Callable.fromStaticFunction(setClipboard);
        io.getClipboardTextFn = cpp.Callable.fromStaticFunction(getClipboard);

        var atlas  = Pointer.fromRaw(io.fonts).ref;
        var width  = 0;
        var height = 0;
        var pixels : Array<Int> = null;
        atlas.getTexDataAsRGBA32(pixels, width, height);

        vtxData = new Float32Array(1000000);
        idxData = new UInt16Array(1000000);

        texture = new ImageResource('imgui_texture', width, height, cast pixels);
        atlas.texID = Pointer.addressOf(texture).rawCast();

        flurry.resources.addResource(texture);

        // Change the imgui style.
        var style = ImGui.getStyle();
        style.windowBorderSize = 0;
        style.frameRounding    = 4;
        style.windowRounding   = 4;
        style.colors[10] = ImVec4.create(0.1, 0.1, 0.1, 1.0);
        style.colors[11] = ImVec4.create(0.1, 0.1, 0.1, 1.0);
        style.colors[12] = ImVec4.create(0.1, 0.1, 0.1, 1.0);

        // Hook into flurry events
        flurry.events.preUpdate.add(newFrame);
        flurry.events.postUpdate.add(render);
        flurry.events.shutdown.add(dispose);
    }

    /**
     * Populates the imgui fields with the latest screen, mouse, keyboard, and gamepad info.
     */
    public function newFrame()
    {
        var io = ImGui.getIO();
        io.displaySize  = ImVec2.create(flurry.display.width, flurry.display.height);
        io.mousePos.x   = flurry.display.mouseX;
        io.mousePos.y   = flurry.display.mouseY;
        io.mouseDown[0] = flurry.input.isMouseDown(1);
        io.mouseDown[1] = flurry.input.isMouseDown(3);
        io.keyCtrl      = flurry.input.isKeyDown(Keycodes.lctrl);
        io.keyAlt       = flurry.input.isKeyDown(Keycodes.lalt);
        io.keyShift     = flurry.input.isKeyDown(Keycodes.lshift);
        io.keySuper     = flurry.input.isKeyDown(Keycodes.lmeta);

        io.keysDown[Scancodes.tab      ] = flurry.input.isKeyDown(Keycodes.tab);
        io.keysDown[Scancodes.left     ] = flurry.input.isKeyDown(Keycodes.left);
        io.keysDown[Scancodes.right    ] = flurry.input.isKeyDown(Keycodes.right);
        io.keysDown[Scancodes.up       ] = flurry.input.isKeyDown(Keycodes.up);
        io.keysDown[Scancodes.down     ] = flurry.input.isKeyDown(Keycodes.down);
        io.keysDown[Scancodes.pageup   ] = flurry.input.isKeyDown(Keycodes.pageup);
        io.keysDown[Scancodes.pagedown ] = flurry.input.isKeyDown(Keycodes.pagedown);
        io.keysDown[Scancodes.home     ] = flurry.input.isKeyDown(Keycodes.home);
        io.keysDown[Scancodes.end      ] = flurry.input.isKeyDown(Keycodes.end);
        io.keysDown[Scancodes.enter    ] = flurry.input.isKeyDown(Keycodes.enter);
        io.keysDown[Scancodes.backspace] = flurry.input.isKeyDown(Keycodes.backspace);
        io.keysDown[Scancodes.escape   ] = flurry.input.isKeyDown(Keycodes.escape);
        io.keysDown[Scancodes.delete   ] = flurry.input.isKeyDown(Keycodes.delete);
        io.keysDown[Scancodes.key_a    ] = flurry.input.isKeyDown(Keycodes.key_a);
        io.keysDown[Scancodes.key_c    ] = flurry.input.isKeyDown(Keycodes.key_c);
        io.keysDown[Scancodes.key_v    ] = flurry.input.isKeyDown(Keycodes.key_v);
        io.keysDown[Scancodes.key_x    ] = flurry.input.isKeyDown(Keycodes.key_x);
        io.keysDown[Scancodes.key_y    ] = flurry.input.isKeyDown(Keycodes.key_y);
        io.keysDown[Scancodes.key_z    ] = flurry.input.isKeyDown(Keycodes.key_z);

        ImGui.newFrame();
    }

    /**
     * Builds the imgui draw data and renders it into its batcher.
     */
    public function render()
    {
        camera.viewport.set(0, 0, flurry.display.width, flurry.display.height);
        camera.size.set_xy(camera.viewport.w, camera.viewport.h);
        camera.update();

        ImGui.render();
        onRender(ImGui.getDrawData());
    }

    /**
     * Cleans up resources used by the batcher and texture.
     */
    public function dispose()
    {
        flurry.resources.removeResource(texture);
    }

    /**
     * Add text to imgui.
     * @param _text Text to add.
     */
    public function onTextInput(_text : String)
    {
        var io = ImGui.getIO();
        io.addInputCharactersUTF8(_text);
    }

    /**
     * Creates immediate geometry and places them in the batcher.
     * @param _dataRawPtr Draw data to render.
     */
    function onRender(_dataRawPtr : RawPointer<ImDrawData>) : Void
    {
        var drawData = Pointer.fromRaw(_dataRawPtr).value;

        var commands  = [];
        var vtxOffset = 0;
        var idxOffset = 0;

        for (i in 0...drawData.cmdListsCount)
        {
            var cmdList   = Pointer.fromRaw(drawData.cmdLists[i]).value;
            var cmdBuffer = cmdList.cmdBuffer.data;
            var vtxBuffer = cmdList.vtxBuffer.data;
            var idxBuffer = cmdList.idxBuffer.data;
            for (j in 0...cmdList.cmdBuffer.size)
            {
                var vtxStart = vtxOffset;
                var idxStart = idxOffset;

                var cmd  = cmdBuffer[j];
                var clip = new Rectangle(cmd.clipRect.x, cmd.clipRect.y, cmd.clipRect.z - cmd.clipRect.x, cmd.clipRect.w - cmd.clipRect.y);
                var t : Pointer<ImageResource> = Pointer.fromRaw(cmd.textureID).reinterpret();

                for (i in 0...cmdList.vtxBuffer.size)
                {
                    vtxData[vtxOffset++] = vtxBuffer[i].pos.x;
                    vtxData[vtxOffset++] = vtxBuffer[i].pos.y;
                    vtxData[vtxOffset++] = 0;
                    vtxData[vtxOffset++] = ((vtxBuffer[i].col) & 0xFF) / 255;
                    vtxData[vtxOffset++] = ((vtxBuffer[i].col >>  8) & 0xFF) / 255;
                    vtxData[vtxOffset++] = ((vtxBuffer[i].col >> 16) & 0xFF) / 255;
                    vtxData[vtxOffset++] = ((vtxBuffer[i].col >> 24) & 0xFF) / 255;
                    vtxData[vtxOffset++] = vtxBuffer[i].uv.x;
                    vtxData[vtxOffset++] = vtxBuffer[i].uv.y;
                }

                for (i in 0...cmdList.idxBuffer.size)
                {
                    idxData[idxOffset++] = idxBuffer[i];
                }

                commands.push(new BufferDrawCommand(
                    vtxData, vtxStart, vtxOffset,
                    idxData, idxStart, idxOffset,
                    Hash.uniqueHash(),
                    Stream,
                    camera.projection,
                    camera.viewInverted,
                    camera.viewport,
                    Triangles,
                    null,
                    flurry.resources.get('std-shader-textured.json', ShaderResource),
                    null,
                    [ t.value ],
                    clip,
                    depth,
                    stencil,
                    true,
                    SrcAlpha,
                    OneMinusSrcAlpha,
                    One,
                    Zero));
            }
        }
        
        // Send commands to renderer backend.
        flurry.renderer.backend.uploadBufferCommands(commands);
        flurry.renderer.backend.submitCommands(cast commands, true);
    }

    // Callbacks

    static function getClipboard(_data : cpp.RawPointer<cpp.Void>) : cpp.ConstCharStar
    {
        return sdl.SDL.getClipboardText();
    }

    static function setClipboard(_data : cpp.RawPointer<cpp.Void>, _text : cpp.ConstCharStar)
    {
        sdl.SDL.setClipboardText(_text);
    }
}
