#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>

using namespace metal;

float2 place(int place, 
             float2 uv,
             uint leadingWidth,
             uint leadingHeight,
             uint trailingWidth,
             uint trailingHeight) {
   
    float aspect_a = float(leadingWidth) / float(leadingHeight);
    float aspect_b = float(trailingWidth) / float(trailingHeight);
    
    float u = uv.x;
    float v = uv.y;
    
    switch (place) {
        case 0: // Stretch
            break;
        case 1: // Aspect Fit
            if (aspect_b > aspect_a) {
                v /= aspect_a;
                v *= aspect_b;
                v += ((aspect_a - aspect_b) / 2) / aspect_a;
            } else if (aspect_b < aspect_a) {
                u /= aspect_b;
                u *= aspect_a;
                u += ((aspect_b - aspect_a) / 2) / aspect_b;
            }
            break;
        case 2: // Aspect Fill
            if (aspect_b > aspect_a) {
                u *= aspect_a;
                u /= aspect_b;
                u += ((1.0 / aspect_a - 1.0 / aspect_b) / 2) * aspect_a;
            } else if (aspect_b < aspect_a) {
                v *= aspect_b;
                v /= aspect_a;
                v += ((1.0 / aspect_b - 1.0 / aspect_a) / 2) * aspect_b;
            }
            break;
        case 3: // Fixed
            u = 0.5 + ((uv.x - 0.5) * leadingWidth) / trailingWidth;
            v = 0.5 + ((uv.y - 0.5) * leadingHeight) / trailingHeight;
            break;
    }

    return float2(u, v);
}

float2 uv(float2 position, float scale, float2 offset, float pixelsPerPoint, float2 containerResolution, float2 contentResolution, float2 textureResolution, int placement) {
    
    // Coordinate
    float2 uv = (position * pixelsPerPoint) / containerResolution;
    
    // Resolution
    uint inputWidth = contentResolution.x;
    uint inputHeight = contentResolution.y;
    uint outputWidth = containerResolution.x;
    uint outputHeight = containerResolution.y;
    
    // Placement
    float2 uvPlacement = place(placement, uv, outputWidth, outputHeight, inputWidth, inputHeight);
    float2 uvScale = float2(scale, scale);
    uvPlacement = (uvPlacement - 0.5) / uvScale + 0.5;
    uvPlacement -= offset / float2(outputWidth, outputHeight);
    
    return uvPlacement;
}

float checker(float2 uv, float checkerSize, uint2 resolution) {
    int x = int(uv.x * float(resolution.x));
    x -= resolution.x / 2;
    int y = int(uv.y * float(resolution.y));
    y -= resolution.y / 2;
    int big = int(checkerSize);
    while (big < 10000) {
        big *= 2;
    }
    bool isX = ((x + big) / int(checkerSize)) % 2 == 0;
    bool isY = ((y + big) / int(checkerSize)) % 2 == 0;
    float light = isX ? (isY ? 0.75 : 0.25) : (isY ? 0.25 : 0.75);
    return light;
}

[[ stitchable ]] half4 zoom(float2 position,
                            SwiftUI::Layer layer,
                            texture2d<half, access::sample> texture,
                            float interpolate,
                            float placement,
                            float2 containerResolution,
                            float2 contentResolution,
                            float scale,
                            float2 offset,
                            float checkerTransparency,
                            float checkerSize,
                            float checkerOpacity,
                            float borderWidth,
                            float borderOpacity,
                            float2 scaleRange,
                            float pixelsPerPoint) {
    
    float2 textureResolution = float2(texture.get_width(), texture.get_height());
    
    float2 uvPlacement = uv(position, scale, offset, pixelsPerPoint, containerResolution, contentResolution, textureResolution, int(placement));
    if (uvPlacement.x < 0.0 || uvPlacement.x > 1.0 || uvPlacement.y < 0.0 || uvPlacement.y > 1.0) {
        return 0.0;
    }
    int2 location = int2(uvPlacement * textureResolution);
    
    half4 color;
    if (interpolate > 0.0) {
        half4 color1 = texture.read(uint2(location + int2(1, 1)));
        half4 color2 = texture.read(uint2(location + int2(1, 0)));
        half4 color3 = texture.read(uint2(location + int2(1, -1)));
        half4 color4 = texture.read(uint2(location + int2(0, 1)));
        half4 color5 = texture.read(uint2(location + int2(0, 0)));
        half4 color6 = texture.read(uint2(location + int2(0, -1)));
        half4 color7 = texture.read(uint2(location + int2(-1, 1)));
        half4 color8 = texture.read(uint2(location + int2(-1, 0)));
        half4 color9 = texture.read(uint2(location + int2(-1, -1)));
        color = (color1 + color2 + color3  + color4 + color5 + color6 + color7 + color8  + color9) / 9;
    } else {
        color = texture.read(uint2(location));
    }
    
    // Checker
    if (checkerTransparency) {
        bool inBounds = false;
        float checkerLight = 0.0;
        if ((uvPlacement.x > 0.0 && uvPlacement.x < 1.0) && (uvPlacement.y > 0.0 && uvPlacement.y < 1.0)) {
            inBounds = true;
            if (scale < 1.0) {
                checkerLight = checker(uvPlacement, checkerSize, uint2(contentResolution.x, contentResolution.y)) * checkerOpacity;
            } else {
                float logScale = log2(scale);
                float logFraction = logScale - floor(logScale);
                float currentScalePower = pow(2.0, floor(logScale));
                float nextScalePower = pow(2.0, floor(logScale) + 1.0);
                float currentSize = max(1.0, checkerSize / currentScalePower);
                float nextSize = max(1.0, checkerSize / nextScalePower);
                float currentChecker = checker(uvPlacement, currentSize, uint2(contentResolution.x, contentResolution.y)) * checkerOpacity;
                float nextChecker = checker(uvPlacement, nextSize, uint2(contentResolution.x, contentResolution.y)) * checkerOpacity;
                float fadeFraction = max(0.0, logFraction * 10.0 - 9.0);
                checkerLight = currentChecker * (1.0 - fadeFraction) + nextChecker * fadeFraction;
            }
        }
        color = half4(half3(checkerLight) * (1.0 - color.a) + color.rgb * color.a,
                       inBounds ? 0.5 + 0.5 * color.a : 0.0);
    }
    
    // Border
    if (scale >= scaleRange.x && borderOpacity > 0.0 && borderWidth > 0.0) {
        float fraction = (scale - scaleRange.x) / (scaleRange.y - scaleRange.x);
        float zoomFade = min(max(fraction, 0.0), 1.0);
        float2 uvBorder = float2(borderWidth / scale,
                                 borderWidth / scale);
        float2 uvResolution = float2(uvPlacement.x * float(contentResolution.x),
                                     uvPlacement.y * float(contentResolution.y));
        float2 uvPixel = float2(uvResolution.x - float(int(uvResolution.x)),
                                uvResolution.y - float(int(uvResolution.y)));
        if (!(uvPixel.x > uvBorder.x && uvPixel.x < 1.0 - uvBorder.x) || !(uvPixel.y > uvBorder.y && uvPixel.y < 1.0 - uvBorder.y)) {
            float brightness = (color.r + color.g + color.b) / 3;
            float xPositiveFade = min(uvPixel.x / uvBorder.x, 1.0);
            float xNegativeFade = min((1.0 - uvPixel.x) / uvBorder.x, 1.0);
            float xFade = xPositiveFade * xNegativeFade;
            float yPositiveFade = min(uvPixel.y / uvBorder.y, 1.0);
            float yNegativeFade = min((1.0 - uvPixel.y) / uvBorder.y, 1.0);
            float yFade = yPositiveFade * yNegativeFade;
            float fade = xFade * yFade;
            float borderAlpha = borderOpacity * (1.0 - fade);
            half4 borderColor = half4(half3(brightness < 0.5 ? 1.0 : 0.0), borderAlpha * zoomFade);
            color = half4(color.rgb * (1.0 - borderColor.a) + borderColor.rgb * borderColor.a, max(color.a, borderColor.a));
        }
    }
    
    return color;
}
