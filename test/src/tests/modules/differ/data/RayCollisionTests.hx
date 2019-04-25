package tests.modules.differ.data;

import uk.aidanlee.flurry.modules.differ.shapes.Ray;
import uk.aidanlee.flurry.modules.differ.shapes.Shape;
import uk.aidanlee.flurry.modules.differ.data.RayCollision;
import uk.aidanlee.flurry.api.maths.Vector;
import buddy.BuddySuite;
import mockatoo.Mockatoo.mock;

using buddy.Should;

class RayCollisionTests extends BuddySuite
{
    public function new()
    {
        describe('RayCollisionTests', {
            it('can copy its values from another ray collision', {
                var r1 = new RayCollision();
                var r2 = new RayCollision();
                r1.shape = mock(Shape);
                r1.ray   = mock(Ray);
                r1.start = 2;
                r1.end   = 7;

                r1.shape.should.not.be(r2.shape);
                r1.ray.should.not.be(r2.ray);
                r1.start.should.not.be(r2.start);
                r1.end.should.not.be(r2.end);

                r2.copy_from(r1);

                r1.shape.should.be(r2.shape);
                r1.ray.should.be(r2.ray);
                r1.start.should.be(r2.start);
                r1.end.should.be(r2.end);
            });

            it('can create a recursive clone of itself', {
                var r1 = new RayCollision();
                r1.shape = mock(Shape);
                r1.ray   = mock(Ray);
                r1.start = 2;
                r1.end   = 7;

                var r2 = r1.clone();
                r2.shape.should.be(r1.shape);
                r2.ray.should.be(r1.ray);
                r2.start.should.be(r1.start);
                r2.end.should.be(r1.end);

                r2.start = 3;
                r2.end   = 6;

                r2.shape.should.be(r1.shape);
                r2.ray.should.be(r1.ray);
                r2.start.should.not.be(r1.start);
                r2.end.should.not.be(r1.end);
            });

            it('can get the start position along the line', {
                var ray = new Ray(new Vector(2, 2), new Vector(12, 12));
                var col = new RayCollision();
                col.ray   = ray;
                col.start = 2;
                col.end   = 6;

                RayCollisionHelper.hitStartX(col).should.be(22);
                RayCollisionHelper.hitStartY(col).should.be(22);
            });

            it('can get the end position along the line', {
                var ray = new Ray(new Vector(2, 2), new Vector(12, 12));
                var col = new RayCollision();
                col.ray   = ray;
                col.start = 2;
                col.end   = 6;

                RayCollisionHelper.hitEndX(col).should.be(62);
                RayCollisionHelper.hitEndY(col).should.be(62);
            });
        });
    }
}
