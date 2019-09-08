package tests.api.resources;

import sys.io.File;
import buddy.SingleSuite;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelList;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelType;
import uk.aidanlee.flurry.api.resources.ResourceSystem;
import uk.aidanlee.flurry.api.resources.ResourceEvents;
import uk.aidanlee.flurry.api.resources.Resource;
import sys.io.abstractions.mock.MockFileSystem;
import sys.io.abstractions.mock.MockFileData;
import mockatoo.Mockatoo.*;

using buddy.Should;
using mockatoo.Mockatoo;

class ResourceSystemTests extends SingleSuite
{
    public function new()
    {
        describe('ResourceSystem', {
            
            it('can create a user defined parcel', {
                var assets : ParcelList = {
                    bytes   : [ { path : '', id : 'bytes' } ],
                    texts   : [ { path : '', id : 'texts' } ],
                    images  : [ { path : '', id : 'images' } ],
                    shaders : [ { path : '', id : 'shaders', ogl3 : null, ogl4 : null, hlsl : null } ]
                };
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                var parcel = system.create(Definition('myParcel', assets));

                parcel.name.should.be('myParcel');
                parcel.type.should.equal(Definition('myParcel', assets));
            });

            it('can create a pre-packaged parcel', {
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                var parcel = system.create(PrePackaged('parcel'));

                parcel.name.should.be('parcel');
                parcel.type.should.equal(PrePackaged('parcel'));
            });

            it('allows manually adding resources to the system', {
                var sys = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                var res = mock(Resource);
                res.id.returns('hello');

                sys.addResource(res);
                sys.get('hello', Resource).should.be(res);
            });

            it('allows manually removing resources from the system', {
                var sys = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                var res = mock(Resource);
                res.id.returns('hello');

                sys.addResource(res);
                sys.get('hello', Resource).should.be(res);
                sys.removeResource(res);
                sys.get.bind('hello', Resource).should.throwType(ResourceNotFoundException);
            });

            it('can load a user defined parcels resources into the system', {
                var files = [
                    '/home/user/text.txt'  => MockFileData.fromText('hello world!'),
                    '/home/user/byte.bin'  => MockFileData.fromText('hello world!'),
                    '/home/user/dots.png'  => MockFileData.fromBytes(haxe.Resource.getBytes('dots-data')),
                    '/home/user/json.json' => MockFileData.fromText(' { "hello" : "world!" } '),
                    '/home/user/shdr.json' => MockFileData.fromText(' { "textures" : [ "defaultTexture" ], "blocks" : [] } '),
                    '/home/user/ogl3_vertex.txt'   => MockFileData.fromText('ogl3_vertex'),
                    '/home/user/ogl3_fragment.txt' => MockFileData.fromText('ogl3_fragment'),
                    '/home/user/ogl4_vertex.txt'   => MockFileData.fromText('ogl4_vertex'),
                    '/home/user/ogl4_fragment.txt' => MockFileData.fromText('ogl4_fragment'),
                    '/home/user/hlsl_vertex.txt'   => MockFileData.fromText('hlsl_vertex'),
                    '/home/user/hlsl_fragment.txt' => MockFileData.fromText('hlsl_fragment')
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                system.create(Definition('myParcel', {
                    texts   : [ { id : 'text', path : '/home/user/text.txt' } ],
                    bytes   : [ { id : 'byte', path : '/home/user/byte.bin' } ],
                    images  : [ { id : 'dots', path : '/home/user/dots.png' } ],
                    shaders : [ { id : 'shdr', path : '/home/user/shdr.json',
                        ogl3 : { vertex : '/home/user/ogl3_vertex.txt', fragment : '/home/user/ogl3_fragment.txt', compiled : false },
                        ogl4 : { vertex : '/home/user/ogl4_vertex.txt', fragment : '/home/user/ogl4_fragment.txt', compiled : false },
                        hlsl : { vertex : '/home/user/hlsl_vertex.txt', fragment : '/home/user/hlsl_fragment.txt', compiled : false }
                    } ]
                })).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();

                var res = system.get('text', TextResource);
                res.id.should.be('text');
                res.content.should.be('hello world!');

                var res = system.get('byte', BytesResource);
                res.id.should.be('byte');
                res.bytes.toString().should.be('hello world!');

                var res = system.get('dots', ImageResource);
                res.id.should.be('dots');
                res.width.should.be(2);
                res.height.should.be(2);

                var res = system.get('shdr', ShaderResource);
                res.id.should.be('shdr');
                res.layout.textures.should.containExactly([ 'defaultTexture' ]);
                res.layout.blocks.should.containExactly([ ]);
                res.ogl3.vertex.should.be('ogl3_vertex');
                res.ogl3.fragment.should.be('ogl3_fragment');
                res.ogl4.vertex.should.be('ogl4_vertex');
                res.ogl4.fragment.should.be('ogl4_fragment');
                res.hlsl.vertex.should.be('hlsl_vertex');
                res.hlsl.fragment.should.be('hlsl_fragment');
            });

            it('can load a pre-packaged parcels resources', {
                var files  = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(File.getBytes('bin/images.parcel'))
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                system.create(PrePackaged('images.parcel')).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();

                var res = system.get('dots', ImageResource);
                res.id.should.be('dots');
                res.width.should.be(2);
                res.height.should.be(2);
            });

            it('can load all the dependencies of a pre-packaged parcel', {
                var files = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(File.getBytes('bin/images.parcel')),
                    'assets/parcels/preload.parcel' => MockFileData.fromBytes(File.getBytes('bin/preload.parcel'))
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                system.create(PrePackaged('preload.parcel')).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();

                system.get('dots'         , ImageResource).should.beType(ImageResource);
                system.get('ubuntu'       , TextResource).should.beType(TextResource);
                system.get('cavesofgallet', TextResource).should.beType(TextResource);
            });

            it('fires events for when images and shaders are added', {
                var files = [
                    '/home/user/dots.png'  => MockFileData.fromBytes(haxe.Resource.getBytes('dots-data')),
                    '/home/user/shdr.json' => MockFileData.fromText(' { "textures" : [ "defaultTexture" ], "blocks" : [] } '),
                    '/home/user/ogl3_vertex.txt'   => MockFileData.fromText('ogl3_vertex'),
                    '/home/user/ogl3_fragment.txt' => MockFileData.fromText('ogl3_fragment'),
                    '/home/user/ogl4_vertex.txt'   => MockFileData.fromText('ogl4_vertex'),
                    '/home/user/ogl4_fragment.txt' => MockFileData.fromText('ogl4_fragment'),
                    '/home/user/hlsl_vertex.txt'   => MockFileData.fromText('hlsl_vertex'),
                    '/home/user/hlsl_fragment.txt' => MockFileData.fromText('hlsl_fragment')
                ];
                var events = new ResourceEvents();
                events.created.add(_created -> {
                    switch _created.type
                    {
                        case Image:
                            var res : ImageResource = cast _created;
                            res.id.should.be('dots');
                            res.width.should.be(2);
                            res.height.should.be(2);
                        case Shader:
                            var res : ShaderResource = cast _created;
                            res.id.should.be('shdr');
                            res.layout.textures.should.containExactly([ 'defaultTexture' ]);
                            res.layout.blocks.should.containExactly([ ]);
                            res.ogl3.vertex.should.be('ogl3_vertex');
                            res.ogl3.fragment.should.be('ogl3_fragment');
                            res.ogl4.vertex.should.be('ogl4_vertex');
                            res.ogl4.fragment.should.be('ogl4_fragment');
                            res.hlsl.vertex.should.be('hlsl_vertex');
                            res.hlsl.fragment.should.be('hlsl_fragment');
                        case _:
                            fail('no other resource type should have been created');
                    }
                });

                var system = new ResourceSystem(events, new MockFileSystem(files, []));
                system.create(Definition('myParcel', {
                    images  : [ { id : 'dots', path : '/home/user/dots.png' } ],
                    shaders : [ { id : 'shdr', path : '/home/user/shdr.json',
                        ogl3 : { vertex : '/home/user/ogl3_vertex.txt', fragment : '/home/user/ogl3_fragment.txt', compiled : false },
                        ogl4 : { vertex : '/home/user/ogl4_vertex.txt', fragment : '/home/user/ogl4_fragment.txt', compiled : false },
                        hlsl : { vertex : '/home/user/hlsl_vertex.txt', fragment : '/home/user/hlsl_fragment.txt', compiled : false }
                    } ]
                })).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
            });

            it('fires events for when images and shaders are removed', {
                var files = [
                    '/home/user/dots.png'  => MockFileData.fromBytes(haxe.Resource.getBytes('dots-data')),
                    '/home/user/shdr.json' => MockFileData.fromText(' { "textures" : [ "defaultTexture" ], "blocks" : [] } '),
                    '/home/user/ogl3_vertex.txt'   => MockFileData.fromText('ogl3_vertex'),
                    '/home/user/ogl3_fragment.txt' => MockFileData.fromText('ogl3_fragment'),
                    '/home/user/ogl4_vertex.txt'   => MockFileData.fromText('ogl4_vertex'),
                    '/home/user/ogl4_fragment.txt' => MockFileData.fromText('ogl4_fragment'),
                    '/home/user/hlsl_vertex.txt'   => MockFileData.fromText('hlsl_vertex'),
                    '/home/user/hlsl_fragment.txt' => MockFileData.fromText('hlsl_fragment')
                ];
                var events = new ResourceEvents();
                events.removed.add(_removed -> {
                    switch _removed.type
                    {
                        case Image:
                            var res : ImageResource = cast _removed;
                            res.id.should.be('dots');
                            res.width.should.be(2);
                            res.height.should.be(2);
                        case Shader:
                            var res : ShaderResource = cast _removed;
                            res.id.should.be('shdr');
                            res.layout.textures.should.containExactly([ 'defaultTexture' ]);
                            res.layout.blocks.should.containExactly([ ]);
                            res.ogl3.vertex.should.be('ogl3_vertex');
                            res.ogl3.fragment.should.be('ogl3_fragment');
                            res.ogl4.vertex.should.be('ogl4_vertex');
                            res.ogl4.fragment.should.be('ogl4_fragment');
                            res.hlsl.vertex.should.be('hlsl_vertex');
                            res.hlsl.fragment.should.be('hlsl_fragment');
                        case _:
                            fail('no other resource type should have been created');
                    }
                });

                var system = new ResourceSystem(events, new MockFileSystem(files, []));
                var parcel = system.create(Definition('myParcel', {
                    images  : [ { id : 'dots', path : '/home/user/dots.png' } ],
                    shaders : [ { id : 'shdr', path : '/home/user/shdr.json',
                        ogl3 : { vertex : '/home/user/ogl3_vertex.txt', fragment : '/home/user/ogl3_fragment.txt', compiled : false },
                        ogl4 : { vertex : '/home/user/ogl4_vertex.txt', fragment : '/home/user/ogl4_fragment.txt', compiled : false },
                        hlsl : { vertex : '/home/user/hlsl_vertex.txt', fragment : '/home/user/hlsl_fragment.txt', compiled : false }
                    } ]
                }));
                parcel.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                parcel.free();
            });

            it('can remove a parcels resources from the system', {
                var files = [
                    '/home/user/text.txt' => MockFileData.fromText('hello world!'),
                    '/home/user/byte.bin' => MockFileData.fromText('hello world!')
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                var parcel = system.create(Definition('myParcel', {
                    texts: [ { id : 'text', path : '/home/user/text.txt' } ],
                    bytes: [ { id : 'byte', path : '/home/user/byte.bin' } ]
                }));
                parcel.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                parcel.free();
                system.get.bind('text', TextResource).should.throwType(ResourceNotFoundException);
                system.get.bind('byte', BytesResource).should.throwType(ResourceNotFoundException);
            });

            it('will reference count resources so they are only removed when no parcels reference them', {
                var files = [
                    '/home/user/text1.txt' => MockFileData.fromBytes(),
                    '/home/user/text2.txt' => MockFileData.fromBytes(),
                    '/home/user/text3.txt' => MockFileData.fromBytes()
                ];
                var system  = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                var parcel1 = system.create(Definition('myParcel1', {
                    texts: [ { id : 'text1', path : '/home/user/text1.txt' } ],
                    bytes: [ { id : 'text2', path : '/home/user/text2.txt' } ]
                }));
                var parcel2 = system.create(Definition('myParcel2', {
                    texts: [ { id : 'text2', path : '/home/user/text2.txt' } ],
                    bytes: [ { id : 'text3', path : '/home/user/text3.txt' } ]
                }));
                parcel1.load();
                parcel2.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                system.get('text1', Resource).id.should.be('text1');
                system.get('text2', Resource).id.should.be('text2');
                system.get('text3', Resource).id.should.be('text3');

                parcel2.free();
                system.get.bind('text3', Resource).should.throwType(ResourceNotFoundException);
                system.get('text1', Resource).id.should.be('text1');
                system.get('text2', Resource).id.should.be('text2');

                parcel1.free();
                system.get.bind('text3', Resource).should.throwType(ResourceNotFoundException);
                system.get.bind('text2', Resource).should.throwType(ResourceNotFoundException);
                system.get.bind('text1', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will decremement the references for pre-packaged parcels', {
                var files  = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(File.getBytes('bin/images.parcel'))
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                var parcel = system.create(PrePackaged('images.parcel'));
                parcel.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                system.get('dots', ImageResource).should.beType(ImageResource);

                parcel.free();

                system.get.bind('dots', ImageResource).should.throwType(ResourceNotFoundException);
            });

            it('will decrement the resources in all pre-packaged parcels dependencies', {
                var files = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(File.getBytes('bin/images.parcel')),
                    'assets/parcels/preload.parcel' => MockFileData.fromBytes(File.getBytes('bin/preload.parcel'))
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                var parcel = system.create(PrePackaged('preload.parcel'));
                parcel.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();

                system.get('dots'         , ImageResource).should.beType(ImageResource);
                system.get('ubuntu'       , TextResource).should.beType(TextResource);
                system.get('cavesofgallet', TextResource).should.beType(TextResource);

                parcel.free();

                system.get.bind('dots'         , ImageResource).should.throwType(ResourceNotFoundException);
                system.get.bind('ubuntu'       , TextResource).should.throwType(ResourceNotFoundException);
                system.get.bind('cavesofgallet', TextResource).should.throwType(ResourceNotFoundException);
            });

            it('will throw an exception trying to fetch a resource which does not exist', {
                var sys = new ResourceSystem(mock(ResourceEvents), new MockFileSystem([], []));
                sys.get.bind('hello', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will throw an exception when trying to load an already loaded parcel', {
                var files = [
                    '/home/user/text.txt' => MockFileData.fromText('hello world!'),
                    '/home/user/byte.bin' => MockFileData.fromText('hello world!')
                ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                var parcel = system.create(Definition('myParcel', {
                    texts: [ { id : 'text', path : '/home/user/text.txt' } ],
                    bytes: [ { id : 'byte', path : '/home/user/byte.bin' } ]
                }));
                parcel.load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                parcel.load.bind().should.throwType(ParcelAlreadyLoadedException);
            });

            it('will throw an exception when trying to load a parcel which has not been added to the system', {
                var system1 = new ResourceSystem(mock(ResourceEvents), new MockFileSystem([], []));
                var system2 = new ResourceSystem(mock(ResourceEvents), new MockFileSystem([], []));

                var parcel = system1.create(PrePackaged(''));
                system2.load.bind(parcel).should.throwType(ParcelNotAddedException);
            });

            it('will thrown an exception when trying to get a resource as the wrong type', {
                var files  = [ '/home/user/text.txt' => MockFileData.fromText('hello world!') ];
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                system.create(Definition('myParcel', {
                    texts: [ { id : 'text', path : '/home/user/text.txt' } ]
                })).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                system.get.bind('text', BytesResource).should.throwType(InvalidResourceTypeException);
            });

            it('contains a callback for when the parcel has finished loading', {
                var result = '';
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                system.create(Definition('myParcel', {}), _ -> result = 'finished').load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                result.should.be('finished');
            });

            it('contains a callback for when the parcel has loaded an individual resource', {
                var files = [
                    '/home/user/text.txt' => MockFileData.fromText('hello world!'),
                    '/home/user/byte.bin' => MockFileData.fromText('hello world!')
                ];

                var results = [];
                var system  = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []));
                system.create(Definition('myParcel', {
                    texts: [ { id : 'text', path : '/home/user/text.txt' } ],
                    bytes: [ { id : 'byte', path : '/home/user/byte.bin' } ]
                }), null, _ -> results.push(_)).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                results.should.containExactly([ 0.5, 1.0 ]);
            });

            it('contains a callback for when the parcel has failed to load', {
                var result = '';
                var system = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []));
                system.create(Definition('myParcel', { texts : [ { id : 'text.txt', path : '' } ] }), null, null, _ -> result = _).load();

                // Wait an amount of time then pump events.
                // Hopefully this will be enough time for the parcel to load.
                Sys.sleep(0.1);

                system.update();
                result.should.not.be('');
            });
        });
    }
}
