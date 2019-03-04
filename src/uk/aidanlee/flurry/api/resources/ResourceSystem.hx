package uk.aidanlee.flurry.api.resources;

import sys.io.File;
import haxe.Json;
import haxe.Unserializer;
import format.png.Tools;
import format.png.Reader;
import hx.concurrent.collection.Queue;
import hx.concurrent.executor.Executor;
import uk.aidanlee.flurry.api.resources.Parcel.ResourceInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ShaderInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ImageInfo;
import uk.aidanlee.flurry.api.resources.Parcel.JSONInfo;
import uk.aidanlee.flurry.api.resources.Parcel.TextInfo;
import uk.aidanlee.flurry.api.resources.Parcel.BytesInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelList;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelData;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.JSONResource;
import uk.aidanlee.flurry.api.resources.Resource.TextResource;
import uk.aidanlee.flurry.api.resources.Resource.BytesResource;
import uk.aidanlee.flurry.api.resources.ResourceEvents.ResourceEventRemoved;
import uk.aidanlee.flurry.api.resources.ResourceEvents.ResourceEventCreated;

using Safety;

enum ParcelEventType
{
    Succeeded;
    Progress;
    Failed;
}

class ResourceSystem
{
    /**
     * Event bus the resource system can fire events into as and when resources and created and removed.
     */
    final events : EventBus;

    /**
     * All parcels loaded in this resource system.
     */
    final parcels : Map<String, Parcel>;

    /**
     * Map of a parcels ID to all the resources IDs contained within it.
     * Stored since the parcel could be modified by the user and theres no way to know whats inside a pre-packed parcel until its unpacked.
     */
    final parcelResources : Map<String, Array<String>>;

    /**
     * Map of all loaded resources by their ID.
     */
    final resourceCache : Map<String, Resource>;

    /**
     * Map of how many times a specific resource has been referenced.
     * Prevents storing multiple of the same resource and ensures they aren't removed when still in use.
     */
    final resourceReferences : Map<String, Int>;

    /**
     * Thread pool to load parcels without blocking the main thread.
     */
    final executor : Executor;

    /**
     * Async event queue so the main thread can be notified when a parcel has been loaded.
     * Main thread then adds the loaded resources to the cache. Removes the need for any manual locking on the cache map.
     */
    final queue : Queue<ParcelEvent>;

    /**
     * Creates a new resources system.
     * Allows the creation and loading of parcels and caching their resources.
     * 
     * @param _threads Number of active threads for loading parcels (defaults 1).
     */
    public function new(_events : EventBus, _threads : Int = 1)
    {
        events             = _events;
        parcels            = new Map();
        parcelResources    = new Map();
        resourceCache      = new Map();
        resourceReferences = new Map();
        queue    = new Queue();
        executor = Executor.create(_threads);
    }

    /**
     * Create a new parcel in this system.
     * @param _name Unique name of the parcel.
     * @param _list List of all of this parcels resources.
     * @return Parcel
     */
    public function createParcel(_name : String, _list : ParcelList, ?_onLoaded : Array<Resource>->Void, ?_onProgress : Float->Void, ?_onFailed : String->Void) : Parcel
    {
        return new Parcel(this, _name, _list, _onLoaded, _onProgress, _onFailed);
    }

    /**
     * Add a parcel to this system.
     * @param _parcel Parcel to add.
     */
    public function addParcel(_parcel : Parcel)
    {
        if (parcels.exists(_parcel.id))
        {
            throw 'ParcelAlreadyAddedException : ${_parcel.id} already exists within this resource system';
        }

        parcels.set(_parcel.id, _parcel);
    }

    /**
     * Manually attempt to add a resource to this system.
     * @param _resource The resource to add.
     */
    public function addResource(_resource : Resource)
    {
        if (!resourceCache.exists(_resource.id))
        {
            resourceCache.set(_resource.id, _resource);
            resourceReferences.set(_resource.id, 1);

            if (Std.is(_resource, ImageResource))
            {
                events.fire(ResourceEvents.Created, new ResourceEventCreated(ImageResource, _resource));
            }
            if (Std.is(_resource, ShaderResource))
            {
                events.fire(ResourceEvents.Created, new ResourceEventCreated(ShaderResource, _resource));
            }
        }
    }

    /**
     * Manually attempt to remove a resource from this system.
     * @param _resource The resource to remove.
     */
    public function removeResource(_resource : Resource)
    {
        if (resourceReferences.get(_resource.id) == 1)
        {
            if (Std.is(resourceCache.get(_resource.id), ImageResource))
            {
                events.fire(ResourceEvents.Removed, new ResourceEventRemoved(ImageResource, resourceCache.get(_resource.id)));
            }
            if (Std.is(resourceCache.get(_resource.id), ShaderResource))
            {
                events.fire(ResourceEvents.Removed, new ResourceEventRemoved(ShaderResource, resourceCache.get(_resource.id)));
            }

            resourceReferences.remove(_resource.id);
            resourceCache.remove(_resource.id);
        }
        else
        {
            resourceReferences.set(_resource.id, resourceReferences.get(_resource.id) - 1);
        }
    }

    /**
     * Load a parcels resources and add them to the system.
     * @param _parcel Parcel name to load.
     */
    public function load(_parcel : String)
    {
        if (parcelResources.exists(_parcel))
        {
            throw 'ParcelAlreadyLoadedException : ${_parcel} is already loaded';
        }

        var parcel = parcels.get(_parcel);

        /**
         * This function is ran in a seperate thread to load all the assets without blocking the main thread.
         * An event is fired with the loaded resources and parcel ID so the main thread can add them.
         */
        var parcelLoader = function() {

            /**
             * If the resource info path is not defined we assume the id is also the path.
             * @param _resource ResourceInfo to get the path for.
             * @return String
             */
            inline function getResourceInfoPath(_resource : ResourceInfo) : String {
                return _resource.path == null ? _resource.id : _resource.path;
            }
            
            try {
                var resources = new Array<Resource>();
                
                var totalResources = calculateTotalResources(parcel.list);
                var loadedIndices  = 0;

                var assets : Array<BytesInfo> = parcel.list.bytes.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(getResourceInfoPath(asset)))
                    {
                        throw 'ResourceSystemResourceNotFoundException failed to load ${asset.id}, ${getResourceInfoPath(asset)} does not exist';
                    }

                    resources.push(new BytesResource(asset.id, sys.io.File.getBytes(getResourceInfoPath(asset))));

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                var assets : Array<TextInfo> = parcel.list.texts.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(getResourceInfoPath(asset)))
                    {
                        throw 'ResourceSystemResourceNotFoundException failed to load ${asset.id}, ${getResourceInfoPath(asset)} does not exist';
                    }

                    resources.push(new TextResource(asset.id, sys.io.File.getContent(getResourceInfoPath(asset))));

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                var assets : Array<JSONInfo> = parcel.list.jsons.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(getResourceInfoPath(asset)))
                    {
                        throw 'ResourceSystemResourceNotFoundException failed to load ${asset.id}, ${getResourceInfoPath(asset)} does not exist';
                    }

                    resources.push(new JSONResource(asset.id, Json.parse(sys.io.File.getContent(getResourceInfoPath(asset)))));

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                var assets : Array<ImageInfo> = parcel.list.images.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(getResourceInfoPath(asset)))
                    {
                        throw 'ResourceSystemResourceNotFoundException failed to load ${asset.id}, ${getResourceInfoPath(asset)} does not exist';
                    }

                    //var bytes = sys.io.File.getBytes(getResourceInfoPath(asset));
                    //var info  = stb.Image.load_from_memory(bytes.getData(), bytes.length, 4);
                    var info = new Reader(File.read(getResourceInfoPath(asset))).read();
                    var head = Tools.getHeader(info);

                    resources.push(new ImageResource(asset.id, head.width, head.height, Tools.extract32(info).getData()));

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                var assets : Array<ShaderInfo> = parcel.list.shaders.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(getResourceInfoPath(asset)))
                    {
                        throw 'ResourceSystemResourceNotFoundException failed to load ${asset.id}, ${getResourceInfoPath(asset)} does not exist';
                    }

                    var layout = Json.parse(sys.io.File.getContent(getResourceInfoPath(asset)));
                    var sourceWebGL = asset.webgl == null ? null : { vertex : sys.io.File.getContent(asset.webgl.vertex), fragment : sys.io.File.getContent(asset.webgl.fragment) };
                    var sourceGL45  = asset.gl45  == null ? null : { vertex : sys.io.File.getContent(asset.gl45.vertex) , fragment : sys.io.File.getContent(asset.gl45.fragment) };
                    var sourceHLSL  = asset.hlsl  == null ? null : { vertex : sys.io.File.getContent(asset.hlsl.vertex) , fragment : sys.io.File.getContent(asset.hlsl.fragment) };

                    resources.push(new ShaderResource(asset.id, layout, sourceWebGL, sourceGL45, sourceHLSL));

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                // Parcels contain serialized pre-existing resources.

                var assets : Array<ParcelInfo> = parcel.list.parcels.or([]);
                for (asset in assets)
                {
                    if (!sys.FileSystem.exists(asset))
                    {
                        throw 'ResourceSystemParcelNotFoundException ${asset} does not exist';
                    }

                    // Get the serialized resource array from the parcel bytes.
                    var parcelData : ParcelData = Unserializer.run(sys.io.File.getBytes(asset).toString());
                    if (parcelData.compressed)
                    {
                        parcelData.serializedArray = haxe.zip.Uncompress.run(parcelData.serializedArray);
                    }

                    // Unserialize the resource array and copy it over.
                    // Our custom resolver uses a fully qualified package name for resources since they come from another project.
                  
                    var parcelResources : Array<Resource> = Unserializer.run(parcelData.serializedArray.toString());
                    for (parcelResource in parcelResources)
                    {
                        resources.push(parcelResource);
                    }

                    queue.push(new ParcelProgressEvent(_parcel, Progress, ++loadedIndices / totalResources ));
                }

                queue.push(new ParcelSucceededEvent(_parcel, Succeeded, resources));
            }
            catch (_exception : String)
            {
                queue.push(new ParcelFailedEvent(_parcel, Failed, _exception));
            }
        }

        executor.submit(parcelLoader);
    }

    /**
     * Frees the resources used by a parcel.
     * Resources are reference counted so if multiple parcels depend on an asset it won't be removed until all parcels are freed.
     * @param _parcel Name of the parcel to free.
     */
    public function free(_parcel : String)
    {
        if (!parcelResources.exists(_parcel))
        {
            throw 'ParcelDoesNotExistException : $_parcel does not exist in this system';
        }

        for (resource in parcelResources.get(_parcel))
        {
            // If there is only 1 reference to this resource we can remove it out right.
            // This is because only the parcel we are freeing references it.
            // Otherwise we deincrement the resources reference and leave it in the system.
            if (resourceReferences.get(resource) == 1)
            {
                if (Std.is(resourceCache.get(resource), ImageResource))
                {
                    events.fire(ResourceEvents.Removed, new ResourceEventRemoved(ImageResource, resourceCache.get(resource)));
                }
                if (Std.is(resourceCache.get(resource), ShaderResource))
                {
                    events.fire(ResourceEvents.Removed, new ResourceEventRemoved(ShaderResource, resourceCache.get(resource)));
                }

                resourceReferences.remove(resource);
                resourceCache.remove(resource);
            }
            else
            {
                resourceReferences.set(resource, resourceReferences.get(resource) - 1);
            }
        }

        parcelResources.remove(_parcel);
    }

    /**
     * Get a loaded resource from this system.
     * @param _id   ID of the resource.
     * @param _type Class type of the resource.
     * @return T
     */
    @:generic public function get<T : Resource>(_id : String, _type : Class<T>) : T
    {
        return cast resourceCache.get(_id);
    }

    /**
     * Processes the resource system.
     * This should be called at regular intervals to retrieve parcel loading status from the separate threads.
     * If this is not frequently called then resource won't appear in the system and parcel loading information won't be available.
     */
    public function update()
    {
        var event = queue.pop();
        while (event != null)
        {
            switch (event.type)
            {
                case Succeeded: onParcelSucceeded(cast event);
                case Progress : onParcelProgress(cast event);
                case Failed   : onParcelFailed(cast event);
            }

            event = queue.pop();
        }
    }

    /**
     * Sums up to number of resources included in a parcel list.
     * @param _list Parcel list to sum.
     * @return Total number of resources.
     */
    function calculateTotalResources(_list : ParcelList) : Int
    {
        var total = 0;
        
        var array : Array<BytesInfo> = _list.bytes.or([]);
        total += array.length;

        var array : Array<TextInfo> = _list.texts.or([]);
        total += array.length;

        var array : Array<JSONInfo> = _list.jsons.or([]);
        total += array.length;

        var array : Array<ImageInfo> = _list.images.or([]);
        total += array.length;

        var array : Array<ShaderInfo> = _list.shaders.or([]);
        total += array.length;

        var array : Array<ParcelInfo> = _list.parcels.or([]);
        total += array.length;

        return total;
    }

    /**
     * When a parcel is loaded this functions is called which adds or increments the reference count on resources in the cache.
     * If a user callback has been specified, it will be called.
     * @param _event Parcel event.
     */
    function onParcelSucceeded(_event : ParcelSucceededEvent)
    {
        var newResources = [];

        for (resource in _event.resources)
        {
            newResources.push(resource.id);

            // Set or increment the resources reference counter.
            if (resourceReferences.exists(resource.id))
            {
                resourceReferences.set(resource.id, resourceReferences.get(resource.id) + 1);
            }
            else
            {
                resourceReferences.set(resource.id, 1);
            }

            // Add the resource to the cache if it doesn't alread exist
            if (!resourceCache.exists(resource.id))
            {
                resourceCache.set(resource.id, resource);

                if (Std.is(resource, ImageResource))
                {
                    events.fire(ResourceEvents.Created, new ResourceEventCreated(ImageResource, resource));
                }
                if (Std.is(resource, ShaderResource))
                {
                    events.fire(ResourceEvents.Created, new ResourceEventCreated(ShaderResource, resource));
                }
            }
        }

        parcelResources.set(_event.parcel, newResources);

        var parcel = parcels.get(_event.parcel);
        if (parcel.onLoaded != null)
        {
            parcel.onLoaded(_event.resources);
        }
    }

    /**
     * Once a parcel loader thread has loaded an asset the user defined progress event is called (if defined).
     * @param _event Parcel event.
     */
    function onParcelProgress(_event : ParcelProgressEvent)
    {
        var parcel = parcels.get(_event.parcel);
        if (parcel.onProgress != null)
        {
            parcel.onProgress(_event.progress);
        }
    }

    /**
     * If a parcel fails to load the user defined failure event is called (if defined).
     * @param _event 
     */
    function onParcelFailed(_event : ParcelFailedEvent)
    {
        var parcel = parcels.get(_event.parcel);
        if (parcel.onFailed != null)
        {
            parcel.onFailed(_event.message);
        }
    }
}

/**
 * Base parcel event class. Parcel events emitted to the thread safe queue should inherit this type.
 */
private class ParcelEvent
{
    /**
     * Unique parcel ID.
     */
    public final parcel : String;

    /**
     * The type of event this will be.
     * Event type should correspond to a class inheriting this type.
     */
    public final type : ParcelEventType;

    public function new(_parcel : String, _type : ParcelEventType)
    {
        parcel = _parcel;
        type   = _type;
    }
}

private class ParcelSucceededEvent extends ParcelEvent
{
    /**
     * All the resources which were loaded and added to the system by this parcel.
     */
    public final resources : Array<Resource>;

    public function new(_parcel : String, _type : ParcelEventType, _resources : Array<Resource>)
    {
        super(_parcel, _type);

        resources = _resources;
    }
}

private class ParcelProgressEvent extends ParcelEvent
{
    /**
     * Normalized value for how many items have been loaded from the parcel.
     * Pre-packed parcels count as a single item since there is no way to tell their contents before deserializing them.
     */
    public final progress : Float;

    public function new(_parcel : String, _type : ParcelEventType, _progress : Float)
    {
        super(_parcel, _type);

        progress = _progress;
    }
}

private class ParcelFailedEvent extends ParcelEvent
{
    /**
     * The exception message thrown which caused the parcel to fail loading.
     */
    public final message : String;

    public function new(_parcel : String, _type : ParcelEventType, _message : String)
    {
        super(_parcel, _type);

        message = _message;
    }
}
