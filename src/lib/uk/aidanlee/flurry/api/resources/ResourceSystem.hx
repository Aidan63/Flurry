package uk.aidanlee.flurry.api.resources;

import haxe.zip.Uncompress;
import hxbit.Serializer;
import haxe.Exception;
import haxe.io.Path;
import rx.Subscription;
import rx.subjects.Behavior;
import rx.observers.IObserver;
import rx.schedulers.IScheduler;
import rx.observables.IObservable;
import uk.aidanlee.flurry.api.resources.Resource;
import uk.aidanlee.flurry.api.resources.Resource.ParcelResource;
import sys.io.abstractions.IFileSystem;

using Safety;
using rx.Observable;

@:nullSafety(Loose) class ResourceSystem
{
    /**
     * Event bus the resource system can fire events into as and when resources and created and removed.
     */
    final events : ResourceEvents;

    /**
     * Access to the engines filesystem.
     */
    final fileSystem : IFileSystem;

    /**
     * The scheduler that will load the parcels.
     */
    final workScheduler : IScheduler;

    /**
     * The scheduler that will run all observers.
     * This should be set to a main thread scheduler if `workScheduler` will execute the subscribe function on a separate thread.
     */
    final syncScheduler : IScheduler;

    /**
     * Map of a parcels ID to all the resources IDs contained within it.
     * Stored since the parcel could be modified by the user and theres no way to know whats inside a pre-packed parcel until its unpacked.
     */
    final parcelResources : Map<String, Array<String>>;

    /**
     * Reference to all other parcels this parcel depends on.
     */
    final parcelDependencies : Map<String, Array<String>>;

    /**
     * All resources stored in this system, keyed by their name.
     */
    final resourceCache : Map<String, Resource>;

    /**
     * How many parcels reference each resource.
     * Prevents storing multiple of the same resource and ensures they aren't removed when still in use.
     */
    final resourceReferences : Map<String, Int>;

    /**
     * Creates a new resources system.
     * Allows the creation and loading of parcels and caching their resources.
     */
    public function new(_events : ResourceEvents, _fileSystem : IFileSystem, _workScheduler : IScheduler, _syncScheduler : IScheduler)
    {
        events             = _events;
        fileSystem         = _fileSystem;
        workScheduler      = _workScheduler;
        syncScheduler      = _syncScheduler;
        parcelResources    = [];
        parcelDependencies = [];
        resourceCache      = [];
        resourceReferences = [];
    }

    /**
     * Loads the provided parcels resources into the system.
     * If the parcel has already been loaded an empty observable is returned.
     * @param _parcel Parcel definition.
     * @return Observable<Float> Observable of loading progress (normalised 0 - 1)
     */
    public function load(_parcel : String) : IObservable<Float>
    {
        if (parcelResources.exists(_parcel))
        {
            return Observable.empty();
        }
        else
        {
            final progress = new Behavior(0.0);

            // This observable performs the loading work.
            // It subscribes on the work scheduler and observable functions are called on the sync scheduler.
            // These are probably some sort of thread pool and them main app thread.
            // We manually track if the loading was successful otherwise we could fire onError and onComplete events.
            // We also recursivly call `loadPrePackaged` for dependencies which could fire onComplete before all resources have loaded.
            Observable
                .create((_observer : IObserver<ParcelEvent>) -> {
                    if (loadPrePackaged(_parcel, _observer))
                    {
                        _observer.onCompleted();
                    }

                    return Subscription.empty();
                })
                .subscribeOn(workScheduler)
                .observeOn(syncScheduler)
                .subscribeFunction(
                    _v -> {
                        switch _v
                        {
                            case Progress(_progress, _resource):
                                addResource(_resource);
                                progress.onNext(_progress);
                            case List(_name, _list):
                                parcelResources[_name] = _list;
                            case Dependency(_name, _depends):
                                parcelDependencies[_name] = _depends;
                        }
                    },
                    progress.onError,
                    progress.onCompleted
                );
    
            return progress;
        }
    }

    /**
     * Free a parcel and its resources from the system.
     * @param _name Parcel name.
     */
    public function free(_name : String)
    {
        if (parcelDependencies.exists(_name))
        {
            for (dep in parcelDependencies[_name].unsafe())
            {
                free(dep);
            }

            parcelDependencies.remove(_name);
        }

        if (parcelResources.exists(_name))
        {
            for (res in parcelResources[_name].unsafe())
            {
                if (resourceCache.exists(res))
                {
                    removeResource(resourceCache[res].unsafe());
                }
            }

            parcelResources.remove(_name);
        }
    }

    /**
     * Manually attempt to add a resource to this system.
     * @param _resource The resource to add.
     */
    public function addResource(_resource : Resource)
    {
        if (resourceReferences.exists(_resource.id))
        {
            resourceReferences[_resource.id] = resourceReferences[_resource.id].unsafe() + 1;
        }
        else
        {
            resourceReferences[_resource.id] = 1;

            resourceCache[_resource.id] = _resource;

            events.created.onNext(_resource);
        }
    }

    /**
     * Manually attempt to remove a resource from this system.
     * @param _resource The resource to remove.
     */
    public function removeResource(_resource : Resource)
    {
        if (resourceReferences.exists(_resource.id))
        {
            var referenceCount = resourceReferences[_resource.id].unsafe();
            if (referenceCount == 1)
            {
                if (resourceCache.exists(_resource.id))
                {
                    events.removed.onNext(resourceCache[_resource.id].unsafe());
                    resourceCache.remove(_resource.id);
                }

                resourceReferences.remove(_resource.id);
            }
            else
            {
                resourceReferences[_resource.id] = (referenceCount - 1);
            }
        }
    }

    /**
     * Get a loaded resource from this system.
     * @param _id   ID of the resource.
     * @param _type Class type of the resource.
     * @return T
     */
    public function get<T : Resource>(_id : String, _type : Class<T>) : T
    {
        if (resourceCache.exists(_id))
        {
            var res = resourceCache[_id].unsafe();
            var obj = Std.downcast(res, _type);
            
            if (obj != null)
            {
                return obj;
            }

            throw new InvalidResourceTypeException(_id, Type.getClassName(_type));
        }
        
        throw new ResourceNotFoundException(_id);
    }

    /**
     * Load a pre-packaged parcel from the disk.
     * @param _file Parcel file name.
     */
    function loadPrePackaged(_file : String, _observer : IObserver<ParcelEvent>) : Bool
    {
        final path = Path.join([ 'assets', 'parcels', _file ]);

        if (!fileSystem.file.exists(path))
        {
            _observer.onError('failed to load "${_file}", "${path}" does not exist');

            return false;
        }

        final serializer = new Serializer();
        final parcel     = serializer.unserialize(Uncompress.run(fileSystem.file.getBytes(path)), ParcelResource);

        if (parcel == null)
        {
            _observer.onError('unable to cast deserialised bytes to a ParcelResource');

            return false;
        }

        if (parcel.depends.length > 0)
        {
            _observer.onNext(Dependency(_file, parcel.depends));

            for (dependency in parcel.depends)
            {
                if (!loadPrePackaged(dependency, _observer))
                {
                    return false;
                }
            }
        }

        for (i => asset in parcel.assets)
        {
            _observer.onNext(
                Progress(i / parcel.assets.length, asset)
            );
        }

        _observer.onNext(List(_file, [ for (res in parcel.assets) res.id ]));

        return true;
    }
}

// #region exceptions

class InvalidResourceTypeException extends Exception
{
    public function new(_resource : String, _type : String)
    {
        super('resource $_resource is not a $_type');
    }
}

class ResourceNotFoundException extends Exception
{
    public function new(_resource : String)
    {
        super('failed to load "$_resource", it does not exist in the system');
    }
}

// #endregion

// #region event classes

private enum ParcelEvent
{
    Progress(_progress : Float, _resource : Resource);
    List(_name : String, _list : Array<String>);
    Dependency(_name : String, _dependencies : Array<String>);
}


// #endregion
