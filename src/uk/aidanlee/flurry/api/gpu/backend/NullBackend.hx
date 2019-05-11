package uk.aidanlee.flurry.api.gpu.backend;

import uk.aidanlee.flurry.api.gpu.batcher.DrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.BufferDrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.GeometryDrawCommand;

class NullBackend implements IRendererBackend
{
    public function new()
    {
        //
    }

    public function clear()
    {
        //
    }

    public function preDraw()
    {
        //
    }

    public function uploadGeometryCommands(_commands : Array<GeometryDrawCommand>)
    {
        //
    }

    public function uploadBufferCommands(_commands : Array<BufferDrawCommand>)
    {
        //
    }

    public function submitCommands(_commands : Array<DrawCommand>, _recordStats : Bool = true)
    {
        //
    }

    public function postDraw()
    {
        //
    }

    public function resize(_width : Int, _height : Int)
    {
        //
    }

    public function cleanup()
    {
        //
    }
}
