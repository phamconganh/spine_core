// ******************************************************************************
// Spine Runtimes Software License v2.5
//
// Copyright (c) 2013-2016, Esoteric Software
// All rights reserved.
//
// You are granted a perpetual, non-exclusive, non-sublicensable, and
// non-transferable license to use, install, execute, and perform the Spine
// Runtimes software and derivative works solely for personal or internal
// use. Without the written permission of Esoteric Software (see Section 2 of
// the Spine Software License Agreement), you may not (a) modify, translate,
// adapt, or develop new applications using the Spine Runtimes or otherwise
// create derivative works or improvements of the Spine Runtimes or (b) remove,
// delete, alter, or obscure any trademarks or any copyright, trademark, patent,
// or other intellectual property or proprietary rights notices on or in the
// Software, including any copy thereof. Redistributions in binary or source
// form must include this license and terms.
//
// THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
// USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// ******************************************************************************

part of spine_core;

class IkConstraint extends Constraint {
  final IkConstraintData data;
  final List<Bone> bones = <Bone>[];
  Bone? target;
  double mix = 1.0;
  int bendDirection = 0;

  IkConstraint(this.data, Skeleton skeleton) {
    mix = data.mix;
    bendDirection = data.bendDirection;

    for (int i = 0; i < data.bones.length; i++)
      bones.add(skeleton.findBone(data.bones[i].name)!);
    target = skeleton.findBone(data.target!.name);
  }

  @override
  int getOrder() => data.order;

  void apply() {
    update();
  }

  @override
  void update() {
    final Bone? target = this.target;
    final List<Bone> bones = this.bones;
    switch (bones.length) {
      case 1:
        apply1(bones[0], target!.worldX, target.worldY, mix);
        break;
      case 2:
        apply2(bones[0], bones[1], target!.worldX, target.worldY, bendDirection,
            mix);
        break;
    }
  }

  void apply1(Bone bone, double targetX, double targetY, double alpha) {
    if (!bone.appliedValid) bone.updateAppliedTransform();
    final Bone p = bone.parent!;
    final double id = 1 / (p.a * p.d - p.b * p.c);
    final double x = targetX - p.worldX, y = targetY - p.worldY;
    final double tx = (x * p.d - y * p.b) * id - bone.ax,
        ty = (y * p.a - x * p.c) * id - bone.ay;
    double rotationIK =
        math.atan2(ty, tx) * MathUtils.radDeg - bone.ashearX - bone.arotation;
    if (bone.ascaleX < 0) rotationIK += 180;
    if (rotationIK > 180)
      rotationIK -= 360;
    else if (rotationIK < -180) rotationIK += 360;
    bone.updateWorldTransformWith(
        bone.ax,
        bone.ay,
        bone.arotation + rotationIK * alpha,
        bone.ascaleX,
        bone.ascaleY,
        bone.ashearX,
        bone.ashearY);
  }

  void apply2(Bone parent, Bone child, double targetX, double targetY,
      int bendDir, double alpha) {
    if (alpha == 0) {
      child.updateWorldTransform();
      return;
    }
    if (!parent.appliedValid) parent.updateAppliedTransform();
    if (!child.appliedValid) child.updateAppliedTransform();
    final double px = parent.ax, py = parent.ay;
    double psx = parent.ascaleX, psy = parent.ascaleY, csx = child.ascaleX;
    int os1 = 0, os2 = 0, s2 = 0;
    if (psx < 0) {
      psx = -psx;
      os1 = 180;
      s2 = -1;
    } else {
      os1 = 0;
      s2 = 1;
    }
    if (psy < 0) {
      psy = -psy;
      s2 = -s2;
    }
    if (csx < 0) {
      csx = -csx;
      os2 = 180;
    } else
      os2 = 0;
    final double cx = child.ax;
    double cy = 0.0,
        cwx = 0.0,
        cwy = 0.0,
        a = parent.a,
        b = parent.b,
        c = parent.c,
        d = parent.d;
    final bool u = (psx - psy).abs() <= 0.0001;
    if (!u) {
      cy = 0.0;
      cwx = a * cx + parent.worldX;
      cwy = c * cx + parent.worldY;
    } else {
      cy = child.ay;
      cwx = a * cx + b * cy + parent.worldX;
      cwy = c * cx + d * cy + parent.worldY;
    }
    final Bone pp = parent.parent!;
    a = pp.a;
    b = pp.b;
    c = pp.c;
    d = pp.d;
    final double id = 1 / (a * d - b * c);
    double x = targetX - pp.worldX, y = targetY - pp.worldY;
    final double tx = (x * d - y * b) * id - px, ty = (y * a - x * c) * id - py;
    x = cwx - pp.worldX;
    y = cwy - pp.worldY;
    final double dx = (x * d - y * b) * id - px, dy = (y * a - x * c) * id - py;
    final double l1 = math.sqrt(dx * dx + dy * dy);
    double l2 = child.data.length * csx, a1 = 0.0, a2 = 0.0;
    outer:
    if (u) {
      l2 *= psx;
      double cos = (tx * tx + ty * ty - l1 * l1 - l2 * l2) / (2 * l1 * l2);
      if (cos < -1)
        cos = -1.0;
      else if (cos > 1) cos = 1.0;
      a2 = math.acos(cos) * bendDir;
      a = l1 + l2 * cos;
      b = l2 * math.sin(a2);
      a1 = math.atan2(ty * a - tx * b, tx * a + ty * b);
    } else {
      a = psx * l2;
      b = psy * l2;
      final double aa = a * a,
          bb = b * b,
          dd = tx * tx + ty * ty,
          ta = math.atan2(ty, tx);
      c = bb * l1 * l1 + aa * dd - aa * bb;
      final double c1 = -2 * bb * l1, c2 = bb - aa;
      d = c1 * c1 - 4 * c2 * c;
      if (d >= 0) {
        double q = math.sqrt(d);
        if (c1 < 0) q = -q;
        q = -(c1 + q) / 2;
        final double r0 = q / c2, r1 = c / q;
        final double r = r0.abs() < r1.abs() ? r0 : r1;
        if (r * r <= dd) {
          y = math.sqrt(dd - r * r) * bendDir;
          a1 = ta - math.atan2(y, r);
          a2 = math.atan2(y / psy, (r - l1) / psx);
          break outer;
        }
      }
      double minAngle = math.pi,
          minX = l1 - a,
          minDist = minX * minX,
          minY = 0.0;
      double maxAngle = 0.0, maxX = l1 + a, maxDist = maxX * maxX, maxY = 0.0;
      c = -a * l1 / (aa - bb);
      if (c >= -1 && c <= 1) {
        c = math.acos(c);
        x = a * math.cos(c) + l1;
        y = b * math.sin(c);
        d = x * x + y * y;
        if (d < minDist) {
          minAngle = c;
          minDist = d;
          minX = x;
          minY = y;
        }
        if (d > maxDist) {
          maxAngle = c;
          maxDist = d;
          maxX = x;
          maxY = y;
        }
      }
      if (dd <= (minDist + maxDist) / 2) {
        a1 = ta - math.atan2(minY * bendDir, minX);
        a2 = minAngle * bendDir;
      } else {
        a1 = ta - math.atan2(maxY * bendDir, maxX);
        a2 = maxAngle * bendDir;
      }
    }
    final double os = math.atan2(cy, cx) * s2;
    double rotation = parent.arotation;
    a1 = (a1 - os) * MathUtils.radDeg + os1 - rotation;
    if (a1 > 180)
      a1 -= 360;
    else if (a1 < -180) a1 += 360;
    parent.updateWorldTransformWith(px, py, rotation + a1 * alpha,
        parent.ascaleX, parent.ascaleY, 0.0, 0.0);
    rotation = child.arotation;
    a2 = ((a2 + os) * MathUtils.radDeg - child.ashearX) * s2 + os2 - rotation;
    if (a2 > 180)
      a2 -= 360;
    else if (a2 < -180) a2 += 360;
    child.updateWorldTransformWith(cx, cy, rotation + a2 * alpha, child.ascaleX,
        child.ascaleY, child.ashearX, child.ashearY);
  }
}
