package uk.aidanlee.resources;

import haxe.io.Bytes;
import snow.api.Debug.def;
import uk.aidanlee.resources.ResourceSystem;
import uk.aidanlee.utils.Hash;

typedef ResourceInfo   = { id : String }
typedef ParcelInfo     = String;
typedef BytesInfo      = ResourceInfo;
typedef TextInfo       = ResourceInfo;
typedef JSONInfo       = ResourceInfo;
typedef ImageInfo      = ResourceInfo;
typedef ShaderInfo     = {
    >ResourceInfo,

    ?webgl : {
        vertex   : String,
        fragment : String
    },

    ?gl45 : {
        vertex   : String,
        fragment : String
    },

    ?hlsl : {
        vertex   : String,
        fragment : String
    }
}

typedef ParcelList = {
    ?bytes   : Array<BytesInfo>,
    ?texts   : Array<TextInfo>,
    ?jsons   : Array<JSONInfo>,
    ?images  : Array<ImageInfo>,
    ?shaders : Array<ShaderInfo>,
    ?parcels : Array<ParcelInfo>
}

typedef ParcelData = {
    compressed : Bool,
    serializedArray : Bytes
}

class Parcel
{
    /**
     * Unique name of this parcel.
     */
    public final id : String;

    /**
     * All the resources this parcel will load.
     */
    public final list : ParcelList;

    /**
     * Callback to be called once the parcel has been loaded.
     * Resource array is all of the resources loaded by this parcel into the system.
     */
    public final onLoaded : (_resources : Array<Resource>)->Void;

    /**
     * Callback to be called when progress has been made loading this parcel.
     * Progress is a normalized value for how many of the parcels resources have been loaded.
     */
    public final onProgress : (_progress : Float)->Void;

    /**
     * Callback to be called if loading the parcel fails.
     * Message is the exception message thrown causing the parcel to fail loading.
     */
    public final onFailed : (_message : String)->Void;

    /**
     * The system this parcel belongs to.
     */
    final system : ResourceSystem;

    /**
     * Manually create a new parcel.
     * @param _system   System this parcel belongs to.
     * @param _onLoaded Function to call once the parcel has been loaded.
     * @param _name     Unique name for this parcel (defaults to a unique hash).
     * @param _list     List of resources to load with this parcel (defaults to empty parcel list).
     */
    public function new(_system : ResourceSystem, ?_name : String, ?_list : ParcelList, ?_onLoaded : Array<Resource>->Void, ?_onProgress : Float->Void, ?_onFailed : String->Void)
    {
        system = _system;
        id     = def(_name, Hash.uniqueID());
        list   = def(_list, {});

        onLoaded   = _onLoaded;
        onProgress = _onProgress;
        onFailed   = _onFailed;

        system.parcels.set(id, this);
    }

    /**
     * Load the resources listed in this parcel.
     */
    public function load()
    {
        system.load(id);
    }

    /**
     * Free the resouces listen in this parcel.
     */
    public function free()
    {
        system.free(id);
    }
}
