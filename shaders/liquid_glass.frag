// Edge refraction and body tone for the fallback glass surface.

#include <flutter/runtime_effect.glsl>

// ImageFilter.shader convention: the engine writes the texture size into the
// leading vec2, and the leading sampler2D is the filter input.
uniform vec2 u_size;
uniform float u_corner_radius;
uniform float u_edge_width;
uniform float u_refraction;
uniform float u_specular;
// How the body lifts the background layer:
//   lift * (1 - L)^power + gain * L + floor
// after which chroma keeps that fraction of the backing's own colour. The values
// come from Dart, per brightness; see glassTone.
uniform float u_body_lift;
uniform float u_body_power;
uniform float u_body_gain;
uniform float u_body_floor;
uniform float u_body_chroma;
uniform sampler2D u_texture;

out vec4 frag_color;

// Signed distance to a rounded rectangle; negative inside.
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / u_size;

#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec2 halfSize = u_size * 0.5;
  vec2 p = frag - halfSize;
  float radius = min(u_corner_radius, min(halfSize.x, halfSize.y));

  float dist = sdRoundRect(p, halfSize, radius);
  // Outside the clip, stay transparent.
  if (dist > 0.5) {
    frag_color = vec4(0.0);
    return;
  }

  // Normal, approximated by the gradient of the distance field.
  float e = 1.0;
  vec2 grad = vec2(
    sdRoundRect(p + vec2(e, 0.0), halfSize, radius) -
        sdRoundRect(p - vec2(e, 0.0), halfSize, radius),
    sdRoundRect(p + vec2(0.0, e), halfSize, radius) -
        sdRoundRect(p - vec2(0.0, e), halfSize, radius)
  );
  float gLen = length(grad);
  vec2 normal = gLen > 1e-4 ? grad / gLen : vec2(0.0);

  // Refraction is strongest at the edge and nearly absent in the middle.
  float edge = u_edge_width > 0.0
      ? clamp((-dist) / u_edge_width, 0.0, 1.0)
      : 1.0;
  float lens = pow(1.0 - edge, 2.5);

  vec2 offset = normal * lens * u_refraction / u_size;
  vec2 sampleUv = clamp(uv + offset, vec2(0.001), vec2(0.999));
  vec4 base = texture(u_texture, sampleUv);

  // Specular highlight: two lights, top-left and bottom-right. The more a rim
  // normal points towards either, the brighter that segment. On a circle this
  // gives two arcs; on an elongated capsule it gives a band along each of the
  // top and bottom edges. The ends fall away through lens.
  vec2 l1 = normalize(vec2(-1.0, -1.0));
  vec2 l2 = normalize(vec2(1.0, 1.0));
  float s1 = pow(max(dot(normal, l1), 0.0), 2.0);
  float s2 = pow(max(dot(normal, l2), 0.0), 2.0);
  float spec = (s1 + s2) * lens * u_specular;

  // Body: lift the layer below along the measured curve, keeping part of its
  // colour according to chroma.
  float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
  float lift = u_body_lift * pow(max(1.0 - luma, 0.0), u_body_power)
      + u_body_gain * luma
      + u_body_floor;
  vec3 body = vec3(luma + lift) + u_body_chroma * (base.rgb - vec3(luma));

  frag_color = vec4(clamp(body + vec3(spec), 0.0, 1.0), base.a);
}
