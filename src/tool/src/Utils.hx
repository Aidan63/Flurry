import haxe.io.Path;
import Types.Project;
import Types.Platform;

using StringTools;

class Utils
{
    public static function platform() : Platform
        return Sys.systemName().toLowerCase();

    public static function toolPath(_project : Project)
        return Path.join([ _project.app.output, 'tools', platform() ]);

    public static function releasePath(_project : Project)
        return Path.join([ _project.app.output, platform() ]);

    public static function buildPath(_project : Project)
        return releasePath(_project) + '.build';

    public static function baseTempDir(_project : Project)
        return Path.join([ _project.app.output, 'temp' ]);

    public static function tempFonts(_project : Project)
        return Path.join([ baseTempDir(_project), 'fonts' ]);

    public static function tempSprites(_project : Project)
        return Path.join([ baseTempDir(_project), 'sprites' ]);

    public static function tempAssets(_project : Project)
        return Path.join([ baseTempDir(_project), 'assets' ]);

    public static function executable(_project : Project)
        return switch platform()
        {
            case Windows: Path.join([ releasePath(_project), '${ _project.app.name }.exe' ]);
            case Mac, Linux: Path.join([ releasePath(_project), _project.app.name ]);
        }

    public static function msdfAtlasExecutable()
        return switch platform()
        {
            case Windows : 'msdf-atlas-gen.exe';
            case _ : 'msdf-atlas-gen';
        }

    public static function atlasCreatorExecutable()
        return switch platform()
        {
            case Windows : 'atlas-creator.exe';
            case _ : 'atlas-creator';
        }

    public static function glslangExecutable()
        return switch platform()
        {
            case Windows : 'glslangValidator.exe';
            case _ : 'glslangValidator';
        }

    public static function asepriteExecutable()
        return switch platform()
        {
            case Windows : Path.join([ 'C:', 'Program Files', 'Aseprite', 'aseprite.exe' ]);
            case _ : 'aseprite';
        }
}
