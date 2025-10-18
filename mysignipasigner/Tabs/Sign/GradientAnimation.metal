#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct NodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
};

struct VertexIn {
    float2 position;
};

struct VertexOut {
    float4 position [[position]];
    float time;
    float2 viewSize;
    int page;
};

struct Uniforms {
    int page;
};

/// Passthrough vertex shader
vertex VertexOut gradient_animation_vertex(const device packed_float3* in [[ buffer(0) ]],
                                           constant float &time [[buffer(1)]],
                                           const device packed_float2* viewSize [[buffer(2)]],
                                           constant int &page [[buffer(3)]],
                                           unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(in[vid], 1);
    out.time = time + (float)page * 10.;
    out.viewSize = float2(viewSize->x, viewSize->y);
    out.page = page;
    return out;
}

float noise1(float seed1, float seed2){
    return(
           fract(seed1+12.34567*
                 fract(100.*(abs(seed1*0.91)+seed2+94.68)*
                       fract((abs(seed2*0.41)+45.46)*
                             fract((abs(seed2)+757.21)*
                                   fract(seed1*0.0171))))))
    * 1.0038 - 0.00185;
}

float noise2(float seed1, float seed2, float seed3){
    float buff1 = abs(seed1+100.81) + 1000.3;
    float buff2 = abs(seed2+100.45) + 1000.2;
    float buff3 = abs(noise1(seed1, seed2)+seed3) + 1000.1;
    buff1 = (buff3*fract(buff2*fract(buff1*fract(buff2*0.146))));
    buff2 = (buff2*fract(buff2*fract(buff1+buff2*fract(buff3*0.52))));
    buff1 = noise1(buff1, buff2);
    return(buff1);
}

float noise3(float seed1, float seed2, float seed3) {
    float buff1 = abs(seed1+100.813) + 1000.314;
    float buff2 = abs(seed2+100.453) + 1000.213;
    float buff3 = abs(noise1(buff2, buff1)+seed3) + 1000.17;
    buff1 = (buff3*fract(buff2*fract(buff1*fract(buff2*0.14619))));
    buff2 = (buff2*fract(buff2*fract(buff1+buff2*fract(buff3*0.5215))));
    buff1 = noise2(noise1(seed2,buff1), noise1(seed1,buff2), noise1(seed3,buff3));
    return(buff1);
}

/// Fragment shader for gradient animation
fragment float4 gradient_animation_fragment(VertexOut in [[stage_in]]) {
    float2 st = in.position.xy/in.viewSize.xy;
    st = float2(tan(st.x), sin(st.y));

    st.x += (sin(in.time/2.1)+2.0)*0.12*sin(sin(st.y*st.x+in.time/6.0)*8.2);
    st.y -= (cos(in.time/1.73)+2.0)*0.12*cos(st.x*st.y*5.1-in.time/4.0);

    float3 bg = float3(0.0);

    float3 color1;
    float3 color2;
    float3 color3;
    float3 color4;
    float3 color5;

    if (in.page == 0) {
        // More vibrant red/orange theme
        color1 = float3(1.0, 0.2, 0.0);        // Bright red-orange
        color2 = float3(1.0, 0.0, 0.3);        // Bright red-pink
        color3 = float3(0.8, 0.0, 0.6);        // Bright purple
        color4 = float3(0.9, 0.4, 0.0);        // Bright orange
        color5 = float3(1.0, 0.6, 0.1);        // Bright yellow-orange
    } else if (in.page == 1) {
        // More vibrant blue theme
        color1 = float3(0.0, 0.8, 1.0);        // Bright cyan
        color2 = float3(0.2, 0.4, 1.0);        // Bright blue
        color3 = float3(0.0, 0.2, 1.0);        // Deep blue
        color4 = float3(0.0, 0.6, 0.9);        // Sky blue
        color5 = float3(0.4, 0.9, 1.0);        // Light cyan
    } else if (in.page == 2) {
        // More vibrant green/cyan theme
        color1 = float3(0.0, 1.0, 0.8);        // Bright mint
        color2 = float3(0.0, 0.9, 0.6);        // Bright green-cyan
        color3 = float3(0.0, 0.7, 0.4);        // Emerald
        color4 = float3(0.2, 1.0, 0.7);        // Light green
        color5 = float3(0.4, 0.8, 1.0);        // Aqua
    } else {
        // More vibrant rainbow theme
        color1 = float3(1.0, 0.0, 0.8);        // Bright magenta
        color2 = float3(0.8, 0.0, 0.4);        // Pink
        color3 = float3(0.6, 1.0, 0.0);        // Lime green
        color4 = float3(0.0, 1.0, 0.9);        // Cyan
        color5 = float3(0.3, 0.0, 1.0);        // Purple
    }

    float mixValue = smoothstep(0.0, 0.8, distance(st,float2(sin(in.time/5.0)+0.5,sin(in.time/6.1)+0.5)));
    float3 outColor = mix(color1,bg,mixValue);

    mixValue = smoothstep(0.1, 0.9, distance(st,float2(sin(in.time/3.94)+0.7,sin(in.time/4.2)-0.1)));
    outColor = mix(color2,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.8, distance(st,float2(sin(in.time/3.43)+0.2,sin(in.time/3.2)+0.45)));
    outColor = mix(color3,outColor,mixValue);

    mixValue = smoothstep(0.14, 0.89, distance(st,float2(sin(in.time/5.4)-0.3,sin(in.time/5.7)+0.7)));
    outColor = mix(color4,outColor,mixValue);

    mixValue = smoothstep(0.01, 0.89, distance(st,float2(sin(in.time/9.5)+0.23,sin(in.time/3.95)+0.23)));
    outColor = mix(color5,outColor,mixValue);

    /// ----

    mixValue = smoothstep(0.01, 0.89, distance(st,float2(cos(in.time/8.5)/2.+0.13,sin(in.time/4.95)-0.23)));
    outColor = mix(color1,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.9, distance(st,float2(cos(in.time/6.94)/2.+0.7,sin(in.time/4.112)+0.66)));
    outColor = mix(color2,outColor,mixValue);

    mixValue = smoothstep(0.1, 0.8, distance(st,float2(cos(in.time/4.43)/2.+0.2,sin(in.time/6.2)+0.85)));
    outColor = mix(color3,outColor,mixValue);

    mixValue = smoothstep(0.14, 0.89, distance(st,float2(cos(in.time/10.4)/2.-0.3,sin(in.time/5.7)+0.8)));
    outColor = mix(color4,outColor,mixValue);

    mixValue = smoothstep(0.01, 0.89, distance(st,float2(cos(in.time/4.5)/2.+0.63,sin(in.time/4.95)+0.93)));
    outColor = mix(color5,outColor,mixValue);

    // Reduce noise effect to maintain vibrancy
    float2 st_unwarped = in.position.xy/in.viewSize.xy;
    float3 noise = float3(noise3(st_unwarped.x*0.000001, st_unwarped.y*0.000001, in.time * 1e-15));
    outColor = (outColor * 0.95) - (noise * 0.02); // Reduced noise impact

    return float4(outColor, 1.0);
}