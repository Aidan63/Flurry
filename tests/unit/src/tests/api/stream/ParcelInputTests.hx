package tests.api.stream;

import hxbit.Serializer;
import uk.aidanlee.flurry.api.stream.Compression;
import uk.aidanlee.flurry.api.stream.ParcelInput;
import uk.aidanlee.flurry.api.stream.ParcelOutput.Payload;
import uk.aidanlee.flurry.api.resources.Resource.PixelFormat;
import uk.aidanlee.flurry.api.resources.Resource.TextResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.zip.Compress;
import buddy.BuddySuite;

using Lambda;
using buddy.Should;

class ParcelInputTests extends BuddySuite
{
    public function new()
    {
        describe('ParcelInput Tests', {
            describe('Header Reading', {
                it('will fail reading if the four magic bytes are not present', {
                    final bytes  = Bytes.ofString('BADH');
                    final input  = new BytesInput(bytes);
                    final parcel = new ParcelInput(input);
    
                    switch parcel.readHeader()
                    {
                        case Failure(_):
                        case Success(_): fail('expected to fail reading due to invalid magic bytes');
                    }
                });
    
                it('will fail reading if it cannot detect the compression type', {
                    final bytes  = Bytes.alloc(5);
                    bytes.set(0, 'P'.code);
                    bytes.set(1, 'R'.code);
                    bytes.set(2, 'C'.code);
                    bytes.set(3, 'L'.code);
                    bytes.set(4, 2);
    
                    final input  = new BytesInput(bytes);
                    final parcel = new ParcelInput(input);
    
                    switch parcel.readHeader()
                    {
                        case Failure(_):
                        case Success(_): fail('expected to fail reading due to invalid compression type');
                    }
                });
            });
            describe('Asset Reading', {
                //
            });

            describe('Reading uncompressed serialised resources', {
                final text     = new TextResource('text_id', 'hello world!');
                final expected = createParcel([ SerialisedResource(text) ]);
                final input    = new BytesInput(expected);
                final stream   = new ParcelInput(input);

                switch stream.readHeader()
                {
                    case Success(header):
                        it('should have 1 resource', {
                            header.assets.should.be(1);
                        });
                        it('should be uncompressed', {
                            header.compression.should.equal(Compression.None);
                        });
                    case Failure(reason): fail('unable to read parcel header : reason');
                }
                switch stream.readAsset()
                {
                    case Success(asset):
                        it('will have successfully deserialised the asset', {
                            final resource = (cast asset : TextResource);
                            resource.id.should.be(asset.id);
                            resource.content.should.be(text.content);
                        });
                    case Failure(reason): fail('was not able to read the parcel : $reason');
                }
            });

            describe('Reading uncompressed serialised raw image data', {
                final image    = Bytes.alloc(4 * 4 * 4);
                final expected = createParcel([ ImageData(image, RawBGRA, 4, 4, 'new_image') ]);
                final input    = new BytesInput(expected);
                final stream   = new ParcelInput(input);

                switch stream.readHeader()
                {
                    case Success(header):
                        it('should have 1 resource', {
                            header.assets.should.be(1);
                        });
                        it('should be uncompressed', {
                            header.compression.should.equal(Compression.None);
                        });
                    case Failure(reason): fail('unable to read parcel header : $reason');
                }
                switch stream.readAsset()
                {
                    case Success(asset):
                        it('will have successfully created a new ImageResource', {
                            final resource = (cast asset : ImageResource);
                            resource.name.should.be('new_image');
                            resource.width.should.be(4);
                            resource.height.should.be(4);
                            resource.format.should.equal(PixelFormat.BGRAUNorm);
                        });
                    case Failure(reason): fail('was not able to read the parcel : $reason');
                }
            });

            describe('Reading uncompressed serialised png image data', {
                final image    = toPng(Bytes.alloc(4 * 4 * 4));
                final expected = createParcel([ ImageData(image, Png, 4, 4, 'new_image') ]);
                final input    = new BytesInput(expected);
                final stream   = new ParcelInput(input);

                switch stream.readHeader()
                {
                    case Success(header):
                        it('should have 1 resource', {
                            header.assets.should.be(1);
                        });
                        it('should be uncompressed', {
                            header.compression.should.equal(Compression.None);
                        });
                    case Failure(reason): fail('unable to read parcel header : reason');
                }
                switch stream.readAsset()
                {
                    case Success(asset):
                        it('will have successfully created a new ImageResource', {
                            final resource = (cast asset : ImageResource);
                            resource.name.should.be('new_image');
                            resource.width.should.be(4);
                            resource.height.should.be(4);
                        });
                    case Failure(reason): fail('was not able to read the parcel : $reason');
                }
            });

            describe('Reading uncompressed serialised jpeg image data', {
                final image    = toJpg(Bytes.alloc(4 * 4 * 4));
                final expected = createParcel([ ImageData(image, Jpeg, 4, 4, 'new_image') ]);
                final input    = new BytesInput(expected);
                final stream   = new ParcelInput(input);

                switch stream.readHeader()
                {
                    case Success(header):
                        it('should have 1 resource', {
                            header.assets.should.be(1);
                        });
                        it('should be uncompressed', {
                            header.compression.should.equal(Compression.None);
                        });
                    case Failure(reason): fail('unable to read parcel header : $reason');
                }
                switch stream.readAsset()
                {
                    case Success(asset):
                        it('will have successfully created a new ImageResource', {
                            final resource = (cast asset : ImageResource);
                            resource.name.should.be('new_image');
                            resource.width.should.be(4);
                            resource.height.should.be(4);
                        });
                    case Failure(reason): fail('was not able to read the parcel : $reason');
                }
            });

            describe('Reading compressed parcels', {
                final asset    = new TextResource('text_id', 'hello world!');
                final image    = Bytes.alloc(4 * 4 * 4);
                final expected = createCompressedParcel([ SerialisedResource(asset), ImageData(image, RawBGRA, 4, 4, 'new_image') ], 4);
                final input    = new BytesInput(expected);
                final stream   = new ParcelInput(input);
                final read     = [];

                switch stream.readHeader()
                {
                    case Success(header):
                        it('should have 2 resources', {
                            header.assets.should.be(2);
                        });
                        it('should be uncompressed', {
                            header.compression.should.equal(Compression.Deflate(4, 10000000));
                        });

                        for (_ in 0...header.assets)
                        {
                            switch stream.readAsset()
                            {
                                case Success(asset): read.push(asset);
                                case Failure(_): fail('was not able to read the parcel');
                            }
                        }

                        it('will have successfully deserialised the asset', {
                            final resource = (cast read.find(f -> f.id == asset.id) : TextResource);
                            resource.id.should.be(asset.id);
                            resource.content.should.be(asset.content);
                        });
                        it('will have successfully created a new ImageResource', {
                            final resource = (cast read.find(f -> f.name == 'new_image') : ImageResource);
                            resource.width.should.be(4);
                            resource.height.should.be(4);
                            resource.format.should.equal(PixelFormat.BGRAUNorm);
                        });

                    case Failure(reason): fail('unable to read parcel header : $reason');
                }
            });
        });
    }

    function createParcel(_payload : Array<Payload>) : Bytes
    {
        final output = new BytesOutput();
        output.writeString('PRCL');
        output.writeByte(0);
        output.writeInt32(_payload.length);

        for (entry in _payload)
        {
            switch entry
            {
                case SerialisedResource(_resource):
                    final bytes = new Serializer().serialize(_resource);
                    final len   = bytes.length;

                    output.writeByte(0);
                    output.writeInt32(len);
                    output.write(bytes);
                case ImageData(_bytes, _format, _width, _height, _name):
                    output.writeByte(1);
                    output.writeByte(_format);
                    output.writeInt32(_width);
                    output.writeInt32(_height);
                    output.writeInt32(_name.length);
                    output.writeString(_name);
                    output.writeInt32(_bytes.length);
                    output.write(_bytes);
            }
        }

        return output.getBytes();
    }

    function createCompressedParcel(_payload : Array<Payload>, _level : Int) : Bytes
    {
        final header = new BytesOutput();
        header.writeString('PRCL');
        header.writeByte(1);
        header.writeByte(_level);
        header.writeInt32(10000000);
        header.writeInt32(_payload.length);

        final data = new BytesOutput();
        for (entry in _payload)
        {
            switch entry
            {
                case SerialisedResource(_resource):
                    final bytes = new Serializer().serialize(_resource);
                    final len   = bytes.length;

                    data.writeByte(0);
                    data.writeInt32(len);
                    data.write(bytes);
                case ImageData(_bytes, _format, _width, _height, _name):
                    data.writeByte(1);
                    data.writeByte(_format);
                    data.writeInt32(_width);
                    data.writeInt32(_height);
                    data.writeInt32(_name.length);
                    data.writeString(_name);
                    data.writeInt32(_bytes.length);
                    data.write(_bytes);
            }
        }
        final compressed = Compress.run(data.getBytes(), _level);
        
        header.writeInt32(compressed.length);
        header.write(compressed);

        return header.getBytes();
    }

    function toPng(_bytes : Bytes) : Bytes
    {
        final output = new BytesOutput();
        final writer = new format.png.Writer(output);

        writer.write(format.png.Tools.build32BGRA(4, 4, _bytes));
        output.close();

        return output.getBytes();
    }

    function toJpg(_bytes : Bytes) : Bytes
    {
        final output = new BytesOutput();
        final writer = new format.jpg.Writer(output);

        writer.write({ width: 4, height: 4, quality: 90, pixels: _bytes });
        output.close();

        return output.getBytes();
    }
}