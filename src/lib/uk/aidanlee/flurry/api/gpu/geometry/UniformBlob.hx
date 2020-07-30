package uk.aidanlee.flurry.api.gpu.geometry;

import uk.aidanlee.flurry.api.resources.Resource.ResourceID;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import uk.aidanlee.flurry.api.maths.Hash;
import uk.aidanlee.flurry.api.maths.Matrix;
import uk.aidanlee.flurry.api.maths.Vector4;
import uk.aidanlee.flurry.api.buffers.BufferData;

using Safety;

/**
 * Contains a byte buffer which will be copied to the gpu for use in shaders.
 * Has several functions for updating the attributes contained within.
 */
@ignoreInstrument class UniformBlob
{
    /**
     * ID of the uniform blob.
     * This ID is the name hashed.
     */
    public final id : ResourceID;

    /**
     * The name of the uniform blob.
     * This name should match to a buffer found in the shader.
     */
    public final name : String;

    /**
     * Buffer bytes data.
     */
    public final buffer : BufferData;

    /**
     * Stores the byte offset of each attribute in the buffer based on attribute name.
     * 
     * Will eventually be useful for dealing with shader block alignment.
     */
    final locations : Map<String, Int>;

    /**
     * Create a new uniform blob.
     * @param _name Name of the blob.
     * @param _buffer Buffer bytes.
     * @param _locations Locations of all the attributes in the buffer.
     */
    public function new(_name : String, _buffer : BufferData, _locations : Map<String, Int>)
    {
        id        = Hash.uniqueHash();
        name      = _name;
        buffer    = _buffer;
        locations = _locations;
    }

    /**
     * Copies a matrix into the uniform buffer.
     * @param _name Attribute name.
     * @param _matrix Matrix object to copy.
     */
    public function setMatrix(_name : String, _matrix : Matrix)
    {
        if (locations.exists(_name))
        {
            final byteOffset = buffer.byteOffset + locations[_name].unsafe();
            final byteMatrix = (_matrix : BufferData);

            buffer.bytes.blit(byteOffset, byteMatrix.bytes, byteMatrix.byteOffset, 64);
        }
    }

    /**
     * Copies a vector into the uniform buffer.
     * @param _name Attribute name.
     * @param _vector Vector object to copy.
     */
    public function setVector4(_name : String, _vector : Vector4)
    {
        if (locations.exists(_name))
        {
            final byteOffset = buffer.byteOffset + locations[_name].unsafe();
            final byteVector = (_vector : BufferData);

            buffer.bytes.blit(byteOffset, byteVector.bytes, byteVector.byteOffset, 16);
        }
    }
}

class UniformBlobBuilder
{
    final name : String;

    final writer : BytesBuffer;

    final locations : Map<String, Int>;

    var byteOffset : Int;

    public function new(_name : String)
    {
        name       = _name;
        writer     = new BytesBuffer();
        locations  = [];
        byteOffset = 0;
    }

    public function addMatrix(_name : String, ?_matrix : Matrix) : UniformBlobBuilder
    {
        locations[_name] = byteOffset;

        byteOffset += 64;

        if (_matrix != null)
        {
            final buffer = (cast _matrix : BufferData);

            writer.addBytes(buffer.bytes, buffer.byteOffset, buffer.byteLength);
        }
        else
        {
            writer.addBytes(Bytes.alloc(64), 0, 64);
        }

        return this;
    }

    public function addVector4(_name : String, ?_vector : Vector4) : UniformBlobBuilder
    {
        locations[_name] = byteOffset;

        byteOffset += 16;

        if (_vector != null)
        {
            final buffer = (cast _vector : BufferData);

            writer.addBytes(buffer.bytes, buffer.byteOffset, buffer.byteLength);
        }
        else
        {
            writer.addBytes(Bytes.alloc(16), 0, 16);
        }

        return this;
    }

    public function uniformBlob() : UniformBlob
    {
        final bytes = writer.getBytes();

        return new UniformBlob(name, new BufferData(bytes, 0, bytes.length), locations);
    }
}
