/**********************************************************************
Copyright (c) 2016 Advanced Micro Devices, Inc. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
********************************************************************/
#ifndef BXDF_CL
#define BXDF_CL

/// Schlick's approximation of Fresnel equtions
float SchlickFresnel(float eta, float ndotw)
{
    const float f = ((1.f - eta) / (1.f + eta)) * ((1.f - eta) / (1.f + eta));
    const float m = 1.f - fabs(ndotw);
    const float m2 = m*m;
    return f + (1.f - f) * m2 * m2 * m;
}

/// Full Fresnel equations
float FresnelDielectric(float etai, float etat, float ndotwi, float ndotwt)
{
    // Parallel and perpendicular polarization
    float rparl = ((etat * ndotwi) - (etai * ndotwt)) / ((etat * ndotwi) + (etai * ndotwt));
    float rperp = ((etai * ndotwi) - (etat * ndotwt)) / ((etai * ndotwi) + (etat * ndotwt));
    return (rparl*rparl + rperp*rperp) * 0.5f;
}

#define DENOM_EPS 1e-8f
#define ROUGHNESS_EPS 0.0001f

enum BxdfFlags
{
    kBxdfFlagsSingular = (1 << 0),
    kBxdfFlagsBrdf = (1 << 1),
    kBxdfFlagsEmissive = (1 << 2),
    kBxdfFlagsTransparency = (1 << 3),
    kBxdfFlagsDiffuse = (1 << 4),

    //Used to mask value from bxdf_flags
    kBxdfFlagsAll = (kBxdfFlagsSingular | kBxdfFlagsBrdf | kBxdfFlagsEmissive | kBxdfFlagsTransparency | kBxdfFlagsDiffuse)
};

enum BxdfUberV2SampledComponent
{
    kBxdfUberV2SampleTransparency = 0,
    kBxdfUberV2SampleCoating = 1,
    kBxdfUberV2SampleReflection = 2,
    kBxdfUberV2SampleRefraction = 3,
    kBxdfUberV2SampleDiffuse = 4
};

/// Returns BxDF flags. Flags stored in first byte of bxdf_flags
int Bxdf_GetFlags(DifferentialGeometry const* dg)
{
    return (dg->mat.flags & kBxdfFlagsAll);
}

/// Sets BxDF flags. Flags stored in first byte of bxdf_flags
void Bxdf_SetFlags(DifferentialGeometry *dg, int flags)
{
    dg->mat.flags &= 0xffffff00; //Reset flags
    dg->mat.flags |= flags; //Set new flags
}

/// Return BxDF sampled component. Sampled component stored in second byte of bxdf_flags
int Bxdf_UberV2_GetSampledComponent(DifferentialGeometry const* dg)
{
    return (dg->mat.flags >> 8) & 0xff;
}

/// Sets BxDF sampled component. Sampled component stored in second byte of bxdf_flags
void Bxdf_UberV2_SetSampledComponent(DifferentialGeometry *dg, int sampledComponent)
{
    dg->mat.flags &= 0xffff00ff; //Reset sampled component
    dg->mat.flags |= (sampledComponent << 8); //Set new component
}

#include <../Baikal/Kernels/CL/utils.cl>
#include <../Baikal/Kernels/CL/texture.cl>
#include <../Baikal/Kernels/CL/payload.cl>
#include <../Baikal/Kernels/CL/bxdf_uberv2.cl>

/// Emissive BRDF sampling
float3 Emissive_GetLe(
    // Geometry
    DifferentialGeometry const* dg,
    // Texture args
    TEXTURE_ARG_LIST,
    UberV2ShaderData const* shader_data)
{
    return shader_data->emission_color.xyz;
}

/// BxDF singularity check
bool Bxdf_IsSingular(DifferentialGeometry const* dg)
{
    return (dg->mat.flags & kBxdfFlagsSingular) == kBxdfFlagsSingular;
}

/// BxDF emission check
bool Bxdf_IsEmissive(DifferentialGeometry const* dg)
{
    return (dg->mat.flags & kBxdfFlagsEmissive) == kBxdfFlagsEmissive;
}

/// BxDF singularity check
bool Bxdf_IsBtdf(DifferentialGeometry const* dg)
{
    return (dg->mat.flags & kBxdfFlagsBrdf) == 0;
}

bool Bxdf_IsReflection(DifferentialGeometry const* dg)
{
    return ((dg->mat.flags & kBxdfFlagsBrdf) == kBxdfFlagsBrdf) && ((dg->mat.flags & kBxdfFlagsDiffuse) == kBxdfFlagsDiffuse);
}

bool Bxdf_IsTransparency(DifferentialGeometry const* dg)
{
    return (dg->mat.flags & kBxdfFlagsTransparency) == kBxdfFlagsTransparency;
}

bool Bxdf_IsRefraction(DifferentialGeometry const* dg)
{
    return Bxdf_IsBtdf(dg) && !Bxdf_IsTransparency(dg);
}

#endif // BXDF_CL
