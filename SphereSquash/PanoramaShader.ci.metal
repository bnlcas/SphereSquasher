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

extern "C" float4 panoramaShader(coreimage::sampler src, float w, float h, int mode, float theta, float phi, float fov, coreimage::destination destination)
{
    if(mode == 0){
        float2 extent = float2(w, h);
        float2 uv = fract(src.coord() / extent);// + float2(theta, phi));
        float2 uv_rotated = rotateEquirectangularSamplePoint(uv, 4.0 * theta, 2.0 * phi);// * float2(-1.0, 1.0) + float2(1.0,0.0);;
        float2 samplePt = uv_rotated * extent;// 2.0 * src.extent().wz;
        return src.sample(samplePt);//src.coord());
    } else if (mode == 1){
        //Stereographic/Fisheye
        //old version:
        
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
        // Introduce the phi variable to control the latitude
        
        
        float2 sampleUV = (float2(sample_x,sample_y));


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
        // Peirce Quincuncial Projection
        // This branch implements an approximate inverse of the Peirce quincuncial mapping.
        // (The ShaderToy version typically projects the sphere via stereographic projection
        // and then maps the circle conformally to a square. Here we approximate the inverse.)
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
        
        
    }     else{
        return src.sample(src.coord());
    }
}

