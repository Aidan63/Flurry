package;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import buddy.SingleSuite;
import format.png.Tools;
import format.png.Reader;

using buddy.Should;
using StringTools;

class Test extends SingleSuite
{
    var xvfb : Process;

    public function new()
    {
        describe('System Tests', {
            startup();

            final cases = [
                'BatcherDepth',
                'BatchingGeometry',
                'ClearColour',
                'Colourised',
                'DepthTesting',
                'GeometryDepth',
                'RenderTarget',
                'ShaderUniforms',
                'StencilTesting',
                'Text',
                'Transformations' ];

            for (test in cases)
            {
                build(test);
                screenshot();
                
                var diff = difference(test);

                it('can correctly render the $test test case', {
                    diff.should.beCloseTo(0, 0);
                });

                FileSystem.deleteFile('screenshot.png');
                FileSystem.deleteFile('Build.hxp');
            }

            shutdown();
        });
    }

    function build(_build : String)
    {
        var template = File.getContent('Template.hxp');

        File.saveContent('Build.hxp', template.replace('{TEST_CASE}', _build));

        Sys.command('lix', [ 'run', 'build', 'build' ]);
    }

    function screenshot()
    {
        switch Sys.systemName()
        {
            case 'Windows':
                var proc = new Process('bin\\windows-x64\\SystemTests.exe');

                Sys.sleep(1);
                Sys.command('screenshot.exe');

                // For some reason kill / close don't function properly on windows?
                Sys.command('taskkill /f /t /im SystemTests.exe');

            case 'Linux':
                var proc = new Process('bin/linux-x64/SystemTests');

                Sys.sleep(1);
                Sys.command('import', [ '-window', 'root', 'screenshot.png' ]);

                proc.kill();
                proc.close();
        }
    }

    function difference(_test : String) : Float
    {
        var input    = File.read('expected/$_test.png');
        var reader   = new Reader(input);
        var expected = Tools.extract32(reader.read());
        input.close();

        var input  = File.read('screenshot.png');
        var reader = new Reader(input);
        var actual = Tools.extract32(reader.read());
        input.close();

        var difference = 0.0;

        for (x in 0...768)
        {
            for (y in 0...512)
            {
                var pos = y * 768 + x;
                
                difference += Math.abs(expected.get(pos + 0) - actual.get(pos + 0)) / 255;
                difference += Math.abs(expected.get(pos + 1) - actual.get(pos + 1)) / 255;
                difference += Math.abs(expected.get(pos + 2) - actual.get(pos + 2)) / 255;
            }
        }

        return 100 * (difference / 255) / (768 * 512 * 3);
    }

    function startup()
    {
        if (Sys.systemName() == 'Linux')
        {
            Sys.putEnv('DISPLAY', ':99');
            xvfb = new Process('Xvfb', [ ':99', '-screen', '0', '768x512x24' ]);
        }
    }

    function shutdown()
    {
        if (Sys.systemName() == 'Linux')
        {
            xvfb.kill();
            xvfb.close();
        }
    }
}
