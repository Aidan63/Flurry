package uk.aidanlee.flurry.api.gpu.geometry.shapes;

import uk.aidanlee.flurry.api.maths.Vector2;
import uk.aidanlee.flurry.api.maths.Vector3;
import uk.aidanlee.flurry.api.maths.Maths;
import uk.aidanlee.flurry.api.gpu.geometry.Geometry.GeometryOptions;

using Safety;

typedef CircleGeometryOptions = {

    >GeometryOptions,

    var ?x : Float;

    var ?y : Float;

    var ?r : Float;

    var ?rx : Float;

    var ?ry : Float;

    var ?startAngle : Float;

    var ?endAngle : Float;

    var ?smooth : Float;

    var ?steps : Int;
}

class CircleGeometry extends Geometry
{
    public function new(_options : CircleGeometryOptions)
    {
        super(_options);

        _options.endAngle   = _options.endAngle  .or(360);
        _options.startAngle = _options.startAngle.or(  0);

        var radiusX = _options.r.or(32);
        var radiusY = _options.r.or(32);

        radiusX = _options.rx.or(radiusX);
        radiusY = _options.ry.or(radiusY);

        if (_options.steps == null)
        {
            if (_options.smooth == null)
            {
                var max = Maths.max(radiusX, radiusY);
                _options.steps = segmentsForSmoothCircle(max);
            }
            else
            {
                var max = Maths.max(radiusX, radiusY);
                _options.steps = segmentsForSmoothCircle(max, _options.smooth);
            }
        }

        set(_options.x, _options.y, radiusX, radiusY, _options.steps, _options.startAngle, _options.endAngle);
    }

    /**
     * Creates the circle geometry.
     * @param _x          The x centre position.
     * @param _y          The y centre position.
     * @param _rx         The x radius.
     * @param _ry         The y radius.
     * @param _steps      The number of steps when drawing the ring.
     * @param _startAngle Start angle in degrees.
     * @param _endAngle   End angle in degrees.
     */
    public function set(_x : Float, _y : Float, _rx : Float, _ry : Float, _steps : Int, _startAngle : Float = 0, _endAngle : Float = 360)
    {
        var halfPI = Maths.PI / 2;
        var startAngleRad = Maths.toRadians(_startAngle) - halfPI;
        var endAngleRad   = Maths.toRadians(_endAngle  ) - halfPI;
        var range         = endAngleRad - startAngleRad;

        _steps = Maths.ceil((Maths.abs(range) / (Maths.PI  * 2)) * _steps);

        var theta = range / _steps;
        var tangentalFactor = Maths.tan(theta);
        var radialFactor    = Maths.cos(theta);
        var x = _rx * Maths.cos(startAngleRad);
        var y = _ry * Maths.sin(startAngleRad);

        // Calculate the radio between _x and _y
        var radialRatio = _rx / _ry;
        if (radialRatio == 0)
        {
            radialRatio = 0.00000001;
        }

        var index      = 0;
        var segmentPos = new Array<Vector3>();
        for (i in 0..._steps + 1)
        {
            var tx = x;
            var ty = y / radialRatio;

            var segment = new Vector3(tx, ty);
            segmentPos.push(segment);

            if (index > 0)
            {
                vertices.push(new Vertex( segment, color, new Vector2() ));
            }

            vertices.push(new Vertex( new Vector3(), color, new Vector2() ));
            vertices.push(new Vertex( segment, color, new Vector2() ));

            var tx = -y;
            var ty = x;

            x += tx * tangentalFactor;
            y += ty * tangentalFactor;

            x *= radialFactor;
            y *= radialFactor;

            index++;
        }

        vertices.push(new Vertex( segmentPos[_steps], color, new Vector2() ));

        transformation.position.set_xy(_x, _y);
    }

    /**
     * Returns the number of segments needed to draw a smooth circle of the provided radius.
     * @param _radius The circles radius.
     * @param _smooth The circles smoothness.
     * @return Int
     */
    function segmentsForSmoothCircle(_radius : Float, _smooth : Float = 5) : Int
    {
        return Std.int(_smooth * Maths.sqrt(_radius));
    }
}
