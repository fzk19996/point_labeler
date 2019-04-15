#version 330 core

layout (location = 0) in vec4  in_vertex;
layout (location = 1) in uint  in_label;
layout (location = 2) in uint  in_visible;

uniform sampler2DRect label_colors;
uniform sampler2D     heightMap;

#include "shaders/color.glsl"

// materials.
uniform mat4 mvp;

uniform bool useRemission;
uniform bool useColor;


uniform bool removeGround;
uniform float groundThreshold;

uniform bool planeRemovalNormal;
uniform vec3 planeNormal;
uniform float planeThresholdNormal;
uniform float planeDirectionNormal;
uniform mat4 plane_pose;

uniform vec2 tilePos;
uniform float tileSize;

uniform bool drawInstances;


out vec4 color;

vec3 colormap(float v)
{
    const vec3 interval_colors[] = vec3[](vec3(0.001462, 0.000466, 0.013866), 
                                    vec3(0.316654, 0.07169, 0.48538), 
                                    vec3(0.716387, 0.214982, 0.47529),
                                    vec3(0.9867, 0.535582, 0.38221),
                                    vec3(0.987053, 0.991438, 0.749504));

    int idx = int(min(v * 5, 4.0));
    float alpha = v * 5 - idx * 5;
    
    return mix(interval_colors[max(0, idx-1)], interval_colors[idx], alpha);
}

void main()
{
  // lower 16 bits correspond to the label,
  // upper 16 bits correspond to the class.
  uint label = in_label & uint(0xFFFF);
  uint instance = (in_label >> 16) & uint(0xFFFF);
  
  vec4 in_color = texture(label_colors, vec2(label, 0));
  float in_remission = in_vertex.w;
  
  float range = length(in_vertex.xyz);
  gl_Position = mvp * vec4(in_vertex.xyz, 1.0);

  vec2 v = in_vertex.xy - tilePos;
  
    
  bool visible = (in_visible > uint(0)) && (!removeGround || in_vertex.z > texture(heightMap, v / tileSize + 0.5).r + groundThreshold); 
  
  if(planeRemovalNormal){
    vec3 pn = (plane_pose * vec4(planeNormal, 0.0)).xyz;
    vec3 po = (plane_pose * vec4(0,0,0,1)).xyz;
    
    float scalar_product = dot(in_vertex.xyz - po.xyz, pn);
    
    visible = visible && (planeDirectionNormal * (scalar_product - planeThresholdNormal) < 0);
  }

  
  // if(!visible || range < minRange || range > maxRange) gl_Position = vec4(-10, -10, -10, 1);
  if(!visible) gl_Position = vec4(-10, -10, -10, 1);
  
  
  if(useRemission)
  { 
    if(drawInstances && instance > uint(0))
    {
      in_remission = clamp(in_remission, 0.0, 1.0);
      float r = in_remission * 0.25 + 0.75; // ensure r in [0.75, 1.0]
      if(label == uint(0)) r = in_remission * 0.7 + 0.3; // r in [0.3, 1.0]
      vec3 hsv = vec3(fract(float(instance) / float(5)), 1.0, 1.0);
      hsv.b = max(hsv.b, 0.8);
      
      color = vec4(hsv2rgb(vec3(1, 1, r) * hsv), 1.0);
    }
    else
    {
      in_remission = clamp(in_remission, 0.0, 1.0);
      float r = in_remission * 0.25 + 0.75; // ensure r in [0.75, 1.0]
      if(label == uint(0)) r = in_remission * 0.7 + 0.3; // r in [0.3, 1.0]
      vec3 hsv = rgb2hsv(in_color.rgb);
      hsv.b = max(hsv.b, 0.8);
      
      color = vec4(hsv2rgb(vec3(1, 1, r) * hsv), 1.0);
     // color = vec4(colormap(in_remission), 1.0);
    }
  }
  else 
  {
    color = vec4(in_color.rgb, 1.0);
  }
}
