package tests.api.resources;

import Types.Project;
import Types.Backend;
import commands.Restore;
import parcel.Packer;
import haxe.Exception;
import buddy.SingleSuite;
import uk.aidanlee.flurry.api.resources.ResourceSystem;
import uk.aidanlee.flurry.api.resources.ResourceEvents;
import uk.aidanlee.flurry.api.resources.Resource;
import uk.aidanlee.flurry.api.schedulers.CurrentThreadScheduler;
import sys.io.abstractions.mock.MockFileSystem;
import sys.io.abstractions.mock.MockFileData;
import mockatoo.Mockatoo.*;

using buddy.Should;
using mockatoo.Mockatoo;
using rx.Observable;

class ResourceSystemTests extends SingleSuite
{
    final parcels : Map<String, haxe.io.Bytes>;

    final project : Project;

    public function new()
    {
        parcels = [];
        project = {
            app: {
                name      : '',
                backend   : Backend.Snow,
                codepaths : [],
                main      : '',
                output    : 'bin',
                namespace : ''
            },
            parcels: [ 'assets/assets.json' ]
        };

        new Restore(project).run();
        switch new Packer(project).create('assets/assets.json')
        {
            case Success(data):
                for (parcel in data)
                {
                    parcels[parcel.name] = sys.io.File.getBytes(parcel.file);
                }
            case Failure(message):
                trace('failed to build parcels : $message');
        }

        describe('ResourceSystem', {

            it('allows manually adding resources to the system', {
                final sys = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                final res = new TextResource('hello', '');

                sys.addResource(res);
                sys.get('hello', Resource).should.be(res);
            });

            it('allows manually removing resources from the system', {
                final sys = new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                final res = new TextResource('hello', '');

                sys.addResource(res);
                sys.get('hello', Resource).should.be(res);
                sys.removeResource(res);
                sys.get.bind('hello', Resource).should.throwType(ResourceNotFoundException);
            });

            it('can load a pre-packaged parcels resources', {
                final files  = [ 'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']) ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                system.load([ 'images.parcel' ]);

                final res = system.get('dots', ImageFrameResource);
                res.id.should.be('dots');
                res.width.should.be(2);
                res.height.should.be(2);
            });

            it('fires events for when images and shaders are added', {
                final events = new ResourceEvents();
                events.created.subscribeFunction(_created -> {
                    switch _created.type
                    {
                        case Image:
                            final res : ImageResource = cast _created;
                            res.id.should.be('dots');
                            res.width.should.be(2);
                            res.height.should.be(2);
                        case Shader:
                            final res : ShaderResource = cast _created;
                            res.id.should.be('shdr');
                            res.layout.textures.should.containExactly([ 'defaultTexture' ]);
                            res.layout.blocks.should.containExactly([ ]);
                            res.ogl3.vertex.toString().should.be('ogl3_vertex');
                            res.ogl3.fragment.toString().should.be('ogl3_fragment');
                            res.ogl4.vertex.toString().should.be('ogl4_vertex');
                            res.ogl4.fragment.toString().should.be('ogl4_fragment');
                            res.hlsl.vertex.toString().should.be('hlsl_vertex');
                            res.hlsl.fragment.toString().should.be('hlsl_fragment');
                        case _:
                            fail('no other resource type should have been created');
                    }
                });

                final system = new ResourceSystem(events, new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                system.addResource(new ImageResource('dots', 2, 2, RGBAUNorm, haxe.io.Bytes.alloc(2 * 2 * 4).getData()));
                system.addResource(new ShaderResource(
                    'shdr',
                    new ShaderLayout([ 'defaultTexture' ], []),
                    new ShaderSource(false, haxe.io.Bytes.ofString('ogl3_vertex'), haxe.io.Bytes.ofString('ogl3_fragment')),
                    new ShaderSource(false, haxe.io.Bytes.ofString('ogl4_vertex'), haxe.io.Bytes.ofString('ogl4_fragment')),
                    new ShaderSource(false, haxe.io.Bytes.ofString('hlsl_vertex'), haxe.io.Bytes.ofString('hlsl_fragment'))));
            });

            it('fires events for when images and shaders are removed', {
                final events = new ResourceEvents();
                events.removed.subscribeFunction(_removed -> {
                    switch _removed.type
                    {
                        case Image:
                            final res : ImageResource = cast _removed;
                            res.id.should.be('dots');
                            res.width.should.be(2);
                            res.height.should.be(2);
                        case Shader:
                            final res : ShaderResource = cast _removed;
                            res.id.should.be('shdr');
                            res.layout.textures.should.containExactly([ 'defaultTexture' ]);
                            res.layout.blocks.should.containExactly([ ]);
                            res.ogl3.vertex.toString().should.be('ogl3_vertex');
                            res.ogl3.fragment.toString().should.be('ogl3_fragment');
                            res.ogl4.vertex.toString().should.be('ogl4_vertex');
                            res.ogl4.fragment.toString().should.be('ogl4_fragment');
                            res.hlsl.vertex.toString().should.be('hlsl_vertex');
                            res.hlsl.fragment.toString().should.be('hlsl_fragment');
                        case _:
                            fail('no other resource type should have been created');
                    }
                });

                final image  = new ImageResource('dots', 2, 2, RGBAUNorm, haxe.io.Bytes.alloc(2 * 2 * 4).getData());
                final shader = new ShaderResource(
                    'shdr',
                    new ShaderLayout([ 'defaultTexture' ], []),
                    new ShaderSource(false, haxe.io.Bytes.ofString('ogl3_vertex'), haxe.io.Bytes.ofString('ogl3_fragment')),
                    new ShaderSource(false, haxe.io.Bytes.ofString('ogl4_vertex'), haxe.io.Bytes.ofString('ogl4_fragment')),
                    new ShaderSource(false, haxe.io.Bytes.ofString('hlsl_vertex'), haxe.io.Bytes.ofString('hlsl_fragment')));

                final system = new ResourceSystem(events, new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                system.addResource(image);
                system.addResource(shader);

                system.removeResource(image);
                system.removeResource(shader);
            });

            it('can remove a parcels resources from the system', {
                final files  = [ 'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']) ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                system.load([ 'images.parcel' ]);
                system.free('images.parcel');
                
                system.get.bind('dots', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will reference count resources so they are only removed when no parcels reference them', {
                final files = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']),
                    'assets/parcels/moreImages.parcel' => MockFileData.fromBytes(parcels['moreImages.parcel'])
                ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                system.load([ 'images.parcel', 'moreImages.parcel' ]);

                system.get('dots', Resource).id.should.be('dots');

                system.free('images.parcel');
                system.get('dots', Resource).id.should.be('dots');

                system.free('moreImages.parcel');
                system.get.bind('dots', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will decremement the references for pre-packaged parcels', {
                final files  = [ 'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']) ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);

                system.load([ 'images.parcel' ]);
                system.get('dots', ImageFrameResource).should.beType(ImageFrameResource);
                system.free('images.parcel');

                system.get.bind('dots', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will throw an exception trying to fetch a resource which does not exist', {
                final sys = new ResourceSystem(mock(ResourceEvents), new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                sys.get.bind('hello', Resource).should.throwType(ResourceNotFoundException);
            });

            it('will return an empty observable when trying to load an already loaded parcel', {
                var calls = 0;

                final files = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']),
                    'assets/parcels/preload.parcel' => MockFileData.fromBytes(parcels['preload.parcel'])
                ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                final parcel = 'preload.parcel';

                system.load([ parcel ]);
                system.load([ parcel ]).subscribeFunction(() -> calls++);

                calls.should.be(1);
            });

            it('will thrown an exception when trying to get a resource as the wrong type', {
                final files  = [ 'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel']) ];
                final system = new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current);
                
                system.load([ 'images.parcel' ]);

                // This try catch is needed for hashlink.
                // if we try and bind and use buddys exception catching we get a compile error about not knowing how to cast.
                try
                {
                    system.get('dots', BytesResource);
                }
                catch (e : Exception)
                {
                    e.should.beType(InvalidResourceTypeException);
                }
            });

            it('contains a callback for when the parcel has finished loading', {
                var result = '';

                final files = [
                    'assets/parcels/images.parcel' => MockFileData.fromBytes(parcels['images.parcel'])
                ];
                new ResourceSystem(new ResourceEvents(), new MockFileSystem(files, []), CurrentThreadScheduler.current, CurrentThreadScheduler.current)
                    .load([ 'images.parcel' ])
                    .subscribeFunction(() -> result = 'finished');

                result.should.be('finished');
            });

            it('contains a callback for when the parcel has failed to load', {
                var result = '';
                new ResourceSystem(new ResourceEvents(), new MockFileSystem([], []), CurrentThreadScheduler.current, CurrentThreadScheduler.current)
                    .load([ 'myParcel' ])
                    .subscribeFunction((_error : String) -> result = 'error');

                result.should.be('error');
            });
        });
    }
}
