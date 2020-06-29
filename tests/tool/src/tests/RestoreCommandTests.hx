package tests;

import Types.Unit;
import Types.Result;
import Types.Project;
import haxe.io.Bytes;
import sys.io.abstractions.mock.MockFileSystem;
import commands.Restore;
import buddy.BuddySuite;
import mockatoo.Mockatoo.*;

using mockatoo.Mockatoo;
using buddy.Should;
using Utils;

class RestoreCommandTests extends BuddySuite
{
    public function new()
    {
        describe('Restore Command', {
            it('will invoke npx to download dependencies through lix', {
                final fs      = new MockFileSystem([], []);
                final net     = mock(Net);
                final proc    = mock(Proc);
                final project = project();

                Mockatoo.returns(proc.run(), Success(Unit.value));
                Mockatoo.returns(net.download(), Success(haxe.Resource.getBytes('tgz_data')));

                new Restore(project, fs, net, proc).run().should.equal(Success(Unit.value));

                Mockatoo.verify(proc.run('npx', customMatcher(obj -> {
                    if (obj.length == 2)
                    {
                        final array = (cast obj : Array<String>);

                        return array[0] == 'lix' && array[1] == 'download';
                    }
                    else
                    {
                        return false;
                    }
                })), 1);
            });
            it('will download the msdf-atlas-gen tool', {
                final fs      = new MockFileSystem([], []);
                final net     = mock(Net);
                final proc    = mock(Proc);
                final project = project();

                Mockatoo.returns(proc.run(), Success(Unit.value));
                Mockatoo.returns(net.download(), Success(haxe.Resource.getBytes('tgz_data')));

                new Restore(project, fs, net, proc).run().should.equal(Success(Unit.value));

                Mockatoo.verify(net.download('https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/windows-latest.tar.gz', proc), 1);
                fs.file.exists('bin/tools/windows/msdf-atlas-gen.exe').should.be(true);
                fs.file.getText('bin/tools/windows/msdf-atlas-gen.exe').should.be('hello world');
            });
            it('will download the atlas-creator tool', {
                final fs      = new MockFileSystem([], []);
                final net     = mock(Net);
                final proc    = mock(Proc);
                final project = project();

                Mockatoo.returns(proc.run(), Success(Unit.value));
                Mockatoo.returns(net.download(), Success(haxe.Resource.getBytes('tgz_data')));

                new Restore(project, fs, net, proc).run().should.equal(Success(Unit.value));

                Mockatoo.verify(net.download('https://github.com/flurry-engine/atlas-creator/releases/download/CI/windows-latest.tar.gz', proc), 1);
                fs.file.exists('bin/tools/windows/atlas-creator.exe').should.be(true);
                fs.file.getText('bin/tools/windows/atlas-creator.exe').should.be('hello world');
            });
        });
    }

    function project() : Project
        return {
            app : {
                name      : "ExecutableName",
                namespace : "com.project.namespace",
                output    : "bin",
                main      : "Main",
                codepaths : [ "src" ],
                backend   : Snow
            }
        }
}