package uk.aidanlee.flurry.api.maths;

import uk.aidanlee.flurry.api.buffers.Float32BufferData;

/**
 * 
 */
@:forward(subscribe)
abstract Quaternion(Float32BufferData) from Float32BufferData to Float32BufferData
{
    /**
     * The x component of this quaternion.
     */
    public var x (get, set) : Float;

    inline function get_x() return this[0];
 
    inline function set_x(v) return this[0] = v;

    /**
     * The y component of this quaternion.
     */
    public var y (get, set) : Float;

    inline function get_y() return this[1];

    inline function set_y(v) return this[1] = v;

    /**
     * The z component of this quaternion.
     */
    public var z (get, set) : Float;

    inline function get_z() return this[2];

    inline function set_z(v) return this[2] = v;

    /**
     * The w component of this quaternion.
     */
    public var w (get, set) : Float;

    inline function get_w() return this[3];

    inline function set_w(v) return this[3] = v;

    /**
     * The length of this quaternion.
     */
    public var length (get, never) : Float;

    inline function get_length() return Maths.sqrt(x * x + y * y + z * z + w * w);

    /**
     * The square of this quaternions length.
     */
    public var lengthsq (get, never) : Float;

    inline function get_lengthsq() return x * x + y * y + z * z + w * w;

    /**
     * A normalized instance of this quaternion.
     */
    public var normalized (get, never) : Quaternion;

    inline function get_normalized() : Quaternion {
        var l = length;

        if (l == 0)
        {
            return new Quaternion();
        }
        else
        {
            l = 1 / l;
            return new Quaternion(x * l, y * l, z * l, w * l);
        }
    }

    /**
     * Create a new quaternion instance.
     * @param _x The value of the x component. (default 0)
     * @param _y The value of the y component. (default 0)
     * @param _z The value of the z component. (default 0)
     * @param _w The value of the w component. (default 1)
     */
    public function new(_x : Float = 0, _y : Float = 0, _z : Float = 0, _w : Float = 1)
    {
        this = new Float32BufferData(4);
        this.edit(_data -> {
            _data[0] = _x;
            _data[1] = _y;
            _data[2] = _z;
            _data[3] = _w;
        });
    }

    /**
     * Returns a formatted string representation of this quaternion.
     */
    public function toString() : String
    {
        return ' { x : $x, y : $y, z : $z, w : $w } ';
    }

    /**
     * Checks if this quaternion is equal to another one.
     * @param _q Quaternion to check with.
     * @return Bool
     */
    public function equals(_q : Quaternion) : Bool
    {
        return (_q.x == x) && (_q.y == y) && (_q.z == z) && (_q.w == w);
    }

    /**
     * Copies another quaternions component values into this one.
     * @param _q Quaternion to copy.
     * @return Quaternion
     */
    public function copy(_q : Quaternion) : Quaternion
    {
        return set_xyzw(_q.x, _q.y, _q.z, _q.w);
    }

    /**
     * Returns a new quaternion instance with the same component values as this.
     * @return Quaternion
     */
    public function clone() : Quaternion
    {
        return new Quaternion(x, y, z, w);
    }

    /**
     * Returns an array containing all four quaternion components.
     * @return Array<Float>
     */
    public function toArray() : Array<Float>
    {
        return [ x, y, z, w ];
    }

    /**
     * Sets the quaternion components from an array.
     * @param _a Array containing four elements for the quaternion components. Expected XYZW order.
     * @return Quaternion
     */
    public function fromArray(_a : Array<Float>) : Quaternion
    {
        return set_xyzw(_a[0], _a[1], _a[2], _a[3]);
    }

    /**
     * Sets all four components of this quaternion.
     * @param _x Value for the x component.
     * @param _y Value for the y component.
     * @param _z Value for the z component.
     * @param _w Value for the w component.
     */
    public function set_xyzw(_x : Float, _y : Float, _z : Float, _w : Float) : Quaternion
    {
        return this.edit(_data -> {
            _data[0] = _x;
            _data[1] = _y;
            _data[2] = _z;
            _data[3] = _w;
        });
    }

    /**
     * Sets the x, y, and z components of this quaternion.
     * @param _x Value for the x component.
     * @param _y Value for the y component.
     * @param _z Value for the z component.
     */
    public function set_xyz(_x : Float, _y : Float, _z : Float) : Quaternion
    {
        return this.edit(_data -> {
            _data[0] = _x;
            _data[1] = _y;
            _data[2] = _z;
        });
    }

    // #region maths

    /**
     * Normalize the components in this quaternion.
     * @return Quaternion
     */
    public function normalize() : Quaternion
    {
        var l = length;
        if (l == 0)
        {
            set_xyzw(0, 0, 0, 1);
        }
        else
        {
            l = 1 / l;
            set_xyzw(x * l, y * l, z * l, w * l);
        }

        return this;
    }

    /**
     * Conjugates this quaternion.
     * @return Quaternion
     */
    public function conjugate() : Quaternion
    {
        return set_xyz(x * -1, y * -1, z * -1);
    }

    /**
     * Inverses this quaternion.
     * @return Quaternion
     */
    public function inverse() : Quaternion
    {
        return conjugate().normalize();
    }

    /**
     * Calculates and returns the dot product between this quaternion and another.
     * @param _other Other quaternion to use.
     * @return Float
     */
    public function dot(_other : Quaternion) : Float
    {
        return x * _other.x + y * _other.y + z * _other.z + w * _other.w;
    }

    // #endregion

    // #region operations

    /**
     * Adds a scalar value to all four components.
     * @param _s Scalar to add.
     * @return Quaternion
     */
    public function addScalar(_s : Float) : Quaternion
    {
        return set_xyzw(x + _s, y + _s, z + _s, w + _s);
    }

    /**
     * Adds another quaternion to this one.
     * @param _q Quaternion to add.
     * @return Quaternion
     */
    public function add(_q : Quaternion) : Quaternion
    {
        return set_xyzw(x + _q.x, y + _q.y, z + _q.z, w + _q.w);
    }

    /**
     * Muiltiply this quaternions components with a scalar value.
     * @param _s Scalar value to multiply by.
     * @return Quaternion
     */
    public function multiplyScalar(_s : Float) : Quaternion
    {
        return set_xyzw(x * _s, y * _s, z * _s, w * _s);
    }

    /**
     * Multiplies this quaternion with another.
     * @param _q The quaternion to multiply with.
     * @return Quaternion
     */
    public function multiply(_q : Quaternion) : Quaternion
    {
        final qax = x;
        final qay = y;
        final qaz = z;
        final qaw = w;

        final qbx = _q.x;
        final qby = _q.y;
        final qbz = _q.z;
        final qbw = _q.w;

        return set_xyzw(
            qax * qbw + qaw * qbx + qay * qbz - qaz * qby,
            qay * qbw + qaw * qby + qaz * qbx - qax * qbz,
            qaz * qbw + qaw * qbz + qax * qby - qay * qbx,
            qaw * qbw - qax * qbx - qay * qby - qaz * qbz
        );
    }

    // #endregion

    // #region transformations

    /**
     * Sets this quaternions values from an euler angle.
     * @param _euler Vector containing the euler angle.
     * @param _order Order of components.
     * @return Quaternion
     */
    public function setFromEuler(_euler : Vector3, _order : ComponentOrder = XYZ) : Quaternion
    {
        var _x = x;
        var _y = y;
        var _z = z;
        var _w = w;

        final c1 = Maths.cos(_euler.x / 2);
        final c2 = Maths.cos(_euler.y / 2);
        final c3 = Maths.cos(_euler.z / 2);

        final s1 = Maths.sin(_euler.x / 2);
        final s2 = Maths.sin(_euler.y / 2);
        final s3 = Maths.sin(_euler.z / 2);

        switch (_order)
        {
            case XYZ:
                _x = s1 * c2 * c3 + c1 * s2 * s3;
                _y = c1 * s2 * c3 - s1 * c2 * s3;
                _z = c1 * c2 * s3 + s1 * s2 * c3;
                _w = c1 * c2 * c3 - s1 * s2 * s3;
            case YXZ:
                _x = s1 * c2 * c3 + c1 * s2 * s3;
                _y = c1 * s2 * c3 - s1 * c2 * s3;
                _z = c1 * c2 * s3 - s1 * s2 * c3;
                _w = c1 * c2 * c3 + s1 * s2 * s3;
            case ZXY:
                _x = s1 * c2 * c3 - c1 * s2 * s3;
                _y = c1 * s2 * c3 + s1 * c2 * s3;
                _z = c1 * c2 * s3 + s1 * s2 * c3;
                _w = c1 * c2 * c3 - s1 * s2 * s3;
            case ZYX:
                _x = s1 * c2 * c3 - c1 * s2 * s3;
                _y = c1 * s2 * c3 + s1 * c2 * s3;
                _z = c1 * c2 * s3 - s1 * s2 * c3;
                _w = c1 * c2 * c3 + s1 * s2 * s3;
            case YZX:
                _x = s1 * c2 * c3 + c1 * s2 * s3;
                _y = c1 * s2 * c3 + s1 * c2 * s3;
                _z = c1 * c2 * s3 - s1 * s2 * c3;
                _w = c1 * c2 * c3 - s1 * s2 * s3;
            case XZY:
                _x = s1 * c2 * c3 - c1 * s2 * s3;
                _y = c1 * s2 * c3 - s1 * c2 * s3;
                _z = c1 * c2 * s3 + s1 * s2 * c3;
                _w = c1 * c2 * c3 + s1 * s2 * s3;
        }

        return set_xyzw(_x, _y, _z, _w);
    }

    /**
     * Sets this quaternions value from an axis and an angle.
     * @param _axis Vector containing the axis values.
     * @param _angle The angle value.
     * @return Quaternion
     */
    public function setFromAxisAngle(_axis : Vector3, _angle : Float) : Quaternion
    {
        final halfAngle = _angle / 2;
        final sin       = Maths.sin(halfAngle);

        return set_xyzw(_axis.x * sin, _axis.y * sin, _axis.z * sin, Maths.cos(halfAngle));
    }

    /**
     * Sets this quaternion from a matrix representing a rotation.
     * @param _m Matrix to copy from.
     * @return Quaternion
     */
    public function setFromRotationMatrix(_m : Matrix) : Quaternion
    {
        final m11 = _m[0], m12 = _m[4], m13 = _m[8];
        final m21 = _m[1], m22 = _m[5], m23 = _m[9];
        final m31 = _m[2], m32 = _m[6], m33 = _m[10];
        final tr  = m11 + m22 + m33;

        var _x = x;
        var _y = y;
        var _z = z;
        var _w = w;

        var s = 0.0;

        if (tr > 0) {

            s = 0.5 / Math.sqrt( tr + 1.0 );

            _w = 0.25 / s;
            _x = (m32 - m23) * s;
            _y = (m13 - m31) * s;
            _z = (m21 - m12) * s;

        } else if (m11 > m22 && m11 > m33) {

            s = 2.0 * Math.sqrt(1.0 + m11 - m22 - m33);

            _w = (m32 - m23) / s;
            _x = 0.25 * s;
            _y = (m12 + m21) / s;
            _z = (m13 + m31) / s;

        } else if (m22 > m33) {

            s = 2.0 * Math.sqrt(1.0 + m22 - m11 - m33);

            _w = (m13 - m31) / s;
            _x = (m12 + m21) / s;
            _y = 0.25 * s;
            _z = (m23 + m32) / s;

        } else {

            s = 2.0 * Math.sqrt(1.0 + m33 - m11 - m22);

            _w = (m21 - m12) / s;
            _x = (m13 + m31) / s;
            _y = (m23 + m32) / s;
            _z = 0.25 * s;

        }

        return set_xyzw(_x, _y, _z, _w);
    }

    // #endregion
}