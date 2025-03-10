//
//  PanoramaShader.ci.metal
//  PanoramaCameraViewer
//
//  Created by Lucas, Ben on 7/25/24.
//

#define PI 3.1415926535
#define M_PI 3.1415926535
#define PI_2 1.57079632679
#define M_PI_2 1.57079632679
#define TAU 6.283185307



#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

float wrapInterval(float x){
    if( x < 0.0){
        return x + 1.0;
    }
    if(x > 1.0){
        return x - 1.0;
    }
    return x;
}

float2 wrapUV(float2 uv){
    uv.x = wrapInterval(uv.x);
    uv.y = wrapInterval(uv.y);
    return uv;
}

float3 sphericalToCartesian(float theta, float phi) {
    float x = cos(phi) * cos(theta);
    float y = sin(phi);
    float z = cos(phi) * sin(theta);
    return float3(x, y, z);
}

float2 rotateEquirectangularSamplePoint(float2 uv, float theta, float phi){
    // Convert to equirectangular coordinates in radians
    float lon = uv.x * 2.0 * M_PI - M_PI; // Longitude in range [-pi, pi]
    float lat = uv.y * M_PI - M_PI_2;     // Latitude in range [-pi/2, pi/2]
    
    // Spherical to Cartesian conversion
    float3 cartesian;
    cartesian.x = cos(lat) * cos(lon);
    cartesian.y = sin(lat);
    cartesian.z = cos(lat) * sin(lon);
    
    // Rotation matrix for the longitude (theta) and latitude (phi)
    float3x3 rotationMatrix;
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);

    rotationMatrix[0][0] = cosTheta;
    rotationMatrix[0][1] = 0.0;
    rotationMatrix[0][2] = -sinTheta;
    rotationMatrix[1][0] = sinTheta * sinPhi;
    rotationMatrix[1][1] = cosPhi;
    rotationMatrix[1][2] = cosTheta * sinPhi;
    rotationMatrix[2][0] = sinTheta * cosPhi;
    rotationMatrix[2][1] = -sinPhi;
    rotationMatrix[2][2] = cosTheta * cosPhi;

    // Apply rotation
    float3 rotated = rotationMatrix * cartesian;
    
    // Cartesian to spherical conversion
    float newLon = atan2(rotated.z, rotated.x);
    float newLat = asin(rotated.y);
    
    // Convert back to equirectangular coordinates
    float2 newTexCoords;
    newTexCoords.x = (newLon + M_PI) / (2.0 * M_PI);
    newTexCoords.y = (newLat + M_PI_2) / M_PI;
    return newTexCoords;
}

float2 complex_mult(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Approximate the Peirce quincuncial mapping using a series expansion.
// Input: z as a vec2 (representing a complex number)
// Output: approximated mapped value w (also a vec2)
float2 peirceMapping(float2 z) {
    const float K = 1.85407;
    
    // Scale input: u = (K/PI) * z
    float2 u = (K / PI) * z;
    
    // Compute required powers of u:
    float2 u2 = complex_mult(u, u);
    float2 u3 = complex_mult(u2, u);
    float2 u5 = complex_mult(u3, u2);  // u^5 = u^3 * u^2
    float2 u7 = complex_mult(u5, u2);  // u^7 = u^5 * u^2
    
    // Taylor series for sn(u, 1/sqrt2):
    // sn(u) ≈ u - (1/4)*u³ + (3/80)*u⁵ - (81/10080)*u⁷
    float2 sn_u = u - (1.0/4.0) * u3 + (3.0/80.0) * u5 - (81.0/10080.0) * u7;
    
    // Return the mapped value: w = sn(u) / K
    return sn_u / K;
}

float3 inverseStereographic(float2 p) {
    float r2 = dot(p, p);
    float denom = 1.0 + r2;
    float3 sphere;
    sphere.x = 2.0 * p.x / denom;
    sphere.y = 2.0 * p.y / denom;
    sphere.z = (r2 - 1.0) / denom;
    return sphere;
}



extern "C" float4 panoramaShader(coreimage::sampler src, float w, float h, int mode, float theta, float phi, float fov, coreimage::destination destination)
{
    if(mode == 0){
        float2 extent = float2(w, h);
        float2 uv = fract(src.coord() / extent);// + float2(theta, phi));

        float2 uv_rotated = rotateEquirectangularSamplePoint(uv, 4.0 * theta, 2.0 * phi);// * float2(-1.0, 1.0) + float2(1.0,0.0);;
        float2 samplePt = wrapUV(0.5 + (uv_rotated - 0.5) * (fov)) * extent;// 2.0 * src.extent().wz;
        return src.sample(samplePt);//src.coord());
    } else if (mode == 1){
        //Stereographic/Fisheye
        float aspect = w / h;
        float2 extent = float2(w, h);
        // Normalize coordinates to [-1, 1] and adjust for aspect ratio
        float2 uv = ((src.coord() / extent) * 2.0 - 1.0) * float2(aspect, 1.0);

        float r = length(uv);
        if (r > 1.0){
            return float4(0.0);
        }
                           
        float theta_long = atan2(uv.y, uv.x);// + theta * PI;
        float sample_x = fract((theta_long + PI) / TAU);
        
        float theta_lat = acos((4.0 - pow(r,2.0))/(4.0 + pow(r,2.0)));
        float sample_y = (fov * theta_lat);//, 1.0);
        
        float2 sampleUV = float2(sample_x,sample_y);



        //float2 sampleCoord = sampleUV * extent / 2.0;// 2.0 * src.extent().wz;
        float2 uv_rotated = rotateEquirectangularSamplePoint(sampleUV, 4.0 * theta, 2.0 * (phi) - 1.0);// * float2(-1.0, 1.0) + float2(1.0,0.0);
        float4 input = src.sample(uv_rotated * extent);//src.coord());
        return input;
    } else if (mode == 2){
        //perspective
        theta = 1.0 - theta;
        float2 extent = float2(w, h);
        float2 uv = src.coord() / extent;
        
        float2 texCoord = uv * 2.0 - 1.0;

        // Perspective transformation
        float aspect = 2.0; // Assuming a square viewport
        float tanHalfFov = tan(PI * fov / 2.0);
        float3 direction = normalize(float3(aspect * texCoord.x * tanHalfFov, texCoord.y * tanHalfFov, -1.0));

        // Rotation matrix to center the view around (theta, phi)
        //float3 forward = sphericalToCartesian(PI*theta, PI_2*phi);
        /*float3 forward;
        if(texCoord.x > 0.0){
            forward = sphericalToCartesian(PI*theta - 0.2, PI_2*phi/2.0);
        } else
        {
            forward = sphericalToCartesian(PI*theta, PI_2*phi/2.0);
        }*/
        float3 forward = sphericalToCartesian(PI*theta, PI_2*phi/2.0);
        float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
        float3 up = cross(right, forward);

        float3x3 rotationMatrix = float3x3(right, up, forward);

        // Rotate the direction vector
        float3 rotatedDirection = normalize(rotationMatrix * direction);

        // Convert Cartesian coordinates to spherical coordinates
        float lon = atan2(rotatedDirection.z, rotatedDirection.x);
        float lat = asin(rotatedDirection.y);

        // Map the spherical coordinates to texture coordinates
        float2 equirectangularTexCoords = float2((lon + PI) / (2.0 * PI), (lat + PI / 2.0) / PI) * float2(-1.0, 1.0) + float2(1.0,0.0);;

        float4 input = src.sample(equirectangularTexCoords * extent);//src.coord());
        return input;

    } else if (mode == 3){
        //Piece Quincuncial
        
        float aspect = w / h;
        float2 extent = float2(w, h);
        // Normalize coordinates to [-1, 1] and adjust for aspect ratio
        float2 uv = ((src.coord() / extent) * 2.0 - 1.0) * float2(aspect, 1.0);
        
        float2 mapped = peirceMapping(uv);

        float3 sphere = inverseStereographic(mapped);
            
            // Convert the sphere point into spherical coordinates.
            // Longitude (λ) from atan2, and latitude (φ) from asin(sphere.z).
        float lon = atan2(sphere.y, sphere.x);
        float lat = asin(sphere.z);
            

        float u = (lon + PI) / (2.0 * PI);
        float v = (lat + 0.5 * PI) / PI;
                        
        float2 sampleUV = float2(u,v);

        //float2 sampleCoord = sampleUV * extent / 2.0;// 2.0 * src.extent().wz;
        float2 uv_rotated = rotateEquirectangularSamplePoint(sampleUV, 4.0 * theta, 2.0 * (phi) - 1.0);// * float2(-1.0, 1.0) + float2(1.0,0.0);
        float4 input = src.sample(float2(1.0-uv_rotated.x, uv_rotated.y) * extent);//src.coord());
        return input;
    } else{
        return src.sample(src.coord());
    }
}


/*
Some Scratch Work:
 float2 extent = float2(w, h);
 // Convert the fragment coordinate to normalized square coordinates [-1,1]
 float2 uv = (src.coord() / extent) * 2.0 - 1.0;
 
 // Inverse of the approximate square-to-circle conformal map:
 // The forward map is often approximated by:
 //   squareUV.x = z.x * sqrt(1.0 - 0.5*z.y*z.y)
 //   squareUV.y = z.y * sqrt(1.0 - 0.5*z.x*z.x)
 // Here we “undo” that mapping.
 float denomX = sqrt(max(1.0 - 0.5 * uv.y * uv.y, 0.0001));
 float denomY = sqrt(max(1.0 - 0.5 * uv.x * uv.x, 0.0001));
 float2 z;
 z.x = uv.x / denomX;
 z.y = uv.y / denomY;
 
 // Use the inverse stereographic projection to recover a point on the sphere.
 float r = length(z);
 float c = 2.0 * atan(r);
 float3 spherePoint;
 if(r > 0.0001) {
     spherePoint = float3(sin(c) * z / r, cos(c));
 } else {
     spherePoint = float3(0.0, 0.0, 1.0);
 }
 
 // Optionally rotate the recovered sphere point using theta and phi.
 float3 forward = sphericalToCartesian(PI * theta, PI_2 * phi / 2.0);
 float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
 float3 up = cross(right, forward);
 float3x3 rotationMatrix = float3x3(right, up, forward);
 spherePoint = rotationMatrix * spherePoint;
 
 // Finally, convert the (rotated) sphere point to equirectangular coordinates.
 float lon = atan2(spherePoint.z, spherePoint.x);
 float lat = asin(spherePoint.y);
 float2 equirectangularUV;
 equirectangularUV.x = (lon + M_PI) / (2.0 * M_PI);
 equirectangularUV.y = (lat + M_PI_2) / M_PI;
 float2 samplePt = equirectangularUV * extent;
 return src.sample(samplePt);
 */
