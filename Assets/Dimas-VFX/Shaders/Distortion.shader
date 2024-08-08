Shader "Custom/Dimas/DistortionEffect"
{
	Properties
	{
		[Header(Main Settings)]
	[Toggle(_EMISSION)] _UseMainTex("Use Main Texture", Int) = 0
		[HDR]_TintColor("Tint Color", Color) = (1,1,1,1)
		_TintDistortion("Tint Distortion", Float) = 1
		_MainTex("Main Texture", 2D) = "black" {}
	[Header(Main Settings)]
	[Normal]_NormalTex("Normal(RG) Alpha(A)", 2D) = "bump" {}
	[HDR]_MainColor("Main Color", Color) = (1,1,1,1)
		_Distortion("Distortion", Float) = 100
		[Toggle(USE_REFRACTIVE)] _UseRefractive("Use Refractive Distort", Int) = 0
		_RefractiveStrength("Refractive Strength", Range(-1, 1)) = 0

		[Toggle(_FADING_ON)] _UseSoft("Use Soft Particles", Int) = 0
		_InvFade("Soft Particles Factor", Float) = 3
		[Space]
	[Header(Height Settings)]
	[Toggle(USE_HEIGHT)] _UseHeight("Use Height Map", Int) = 0
		_HeightTex("Height Tex", 2D) = "white" {}
	_Height("_Height", Float) = 0.1
		_HeightUVScrollDistort("Height UV Scroll(XY)", Vector) = (8, 12, 0, 0)

		[Space]
	[Header(Fresnel)]
	[Toggle(USE_FRESNEL)] _UseFresnel("Use Fresnel", Int) = 0
		[HDR]_FresnelColor("Fresnel Color", Color) = (0.5,0.5,0.5,1)
		_FresnelInvert("Fresnel Invert", Range(0, 1)) = 1
		_FresnelPow("Fresnel Pow", Float) = 5
		_FresnelR0("Fresnel R0", Float) = 0.04
		_FresnelDistort("Fresnel Distort", Float) = 1500

		[Space]
	[Header(Cutout)]
	[Toggle(USE_CUTOUT)] _UseCutout("Use Cutout", Int) = 0
		_CutoutTex("Cutout Tex", 2D) = "white" {}
	_Cutout("Cutout", Range(0, 1.2)) = 1
		[HDR]_CutoutColor("Cutout Color", Color) = (1,1,1,1)
		_CutoutThreshold("Cutout Threshold", Range(0, 1)) = 0.015

		[Space]
	[Header(Rendering)]
	[Toggle] _ZWriteMode("ZWrite On?", Int) = 0
		[Enum(Off,0,Front,1,Back,2)] _CullMode("Culling", Float) = 0 //0 = off, 2=back
		[Toggle(USE_ALPHA_CLIPING)] _UseAlphaCliping("Use Alpha Cliping", Int) = 0
		_AlphaClip("Alpha Clip Threshold", Float) = 100
		[Toggle(_FLIPBOOK_BLENDING)] _UseBlending("Use Blending", Int) = 0


	}
		SubShader
	{


		Tags{ "Queue" = "Transparent-10"  "IgnoreProjector" = "True"  "RenderType" = "Transparent" }

		ZWrite[_ZWriteMode]
		Cull[_CullMode]
		Offset -1, -1
		Blend SrcAlpha OneMinusSrcAlpha

	Pass
	{
	

		HLSLPROGRAM

#pragma vertex vert
#pragma fragment frag

#pragma target 4.6

#pragma multi_compile_particles
#pragma multi_compile_instancing

#pragma shader_feature USE_REFRACTIVE
#pragma shader_feature _FADING_ON
#pragma shader_feature USE_FRESNEL
#pragma shader_feature USE_CUTOUT
#pragma shader_feature USE_HEIGHT
#pragma shader_feature USE_ALPHA_CLIPING
#pragma shader_feature _FLIPBOOK_BLENDING
#pragma shader_feature _EMISSION

	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
	#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
	#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/AtmosphericScattering/AtmosphericScattering.hlsl"


	sampler2D _MainTex;
	sampler2D _NormalTex;
	float4 _NormalTex_ST;
	float4 _MainTex_ST;
	half _RefractiveStrength;
	half _InvFade;

	sampler2D _HeightTex;
	float4 _HeightTex_ST;
	half4 _HeightUVScrollDistort;
	half _Height;


	half4 _FresnelColor;
	half _FresnelInvert;
	half _FresnelPow;
	half _FresnelR0;
	half _FresnelDistort;

	sampler2D _CutoutTex;
	float4 _CutoutTex_ST;

	half4 _CutoutColor;
	half _CutoutThreshold;
	half _AlphaClip;
	half _TintDistortion;

	float4 _DepthPyramidScale;
	float4x4 _InverseTransformMatrix;

	UNITY_INSTANCING_BUFFER_START(MyProperties)
		UNITY_DEFINE_INSTANCED_PROP(float4, _MainColor)
#define _MainColor_arr MyProperties
		UNITY_DEFINE_INSTANCED_PROP(float4, _TintColor)
#define _TintColor_arr MyProperties
		UNITY_DEFINE_INSTANCED_PROP(half, _Distortion)
#define _Distortion_arr MyProperties
		UNITY_DEFINE_INSTANCED_PROP(half, _Cutout)
#define _Cutout_arr MyProperties
		UNITY_INSTANCING_BUFFER_END(MyProperties)



		struct appdata
	{
		float4 vertex : POSITION;
#if defined (USE_HEIGHT) || defined (USE_REFRACTIVE) || defined (USE_FRESNEL) 
		half3 normal : NORMAL;
#endif
#ifdef USE_REFRACTIVE
		half4 tangent : TANGENT;
#endif
		half4 color : COLOR;
#ifdef _FLIPBOOK_BLENDING

		float2 uv : TEXCOORD0;
		float4 texcoordBlendFrame : TEXCOORD1;

#else
		float2 uv : TEXCOORD0;
#endif
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f
	{
		float4 vertex : SV_POSITION;
		half4 color : COLOR;
		half4 uvgrab : TEXCOORD0;
#ifdef _FLIPBOOK_BLENDING
			float4 uv : TEXCOORD2;
		fixed blend : TEXCOORD3;
#else
			float2 uv : TEXCOORD2;
#endif

#ifdef USE_CUTOUT
		float2 uvCutout : TEXCOORD4;
#endif
#if defined (_FADING_ON)
		float4 screenPos : TEXCOORD5;
#endif
#ifdef _EMISSION
		float2 mainUV : TEXCOORD6;
#endif
#ifdef USE_FRESNEL
#if  defined (USE_HEIGHT)
		half4 localPos : TEXCOORD7;
		half3 viewDir : TEXCOORD8;
#else
		half fresnel : TEXCOORD7;
#endif
#endif
#ifdef USE_REFRACTIVE
		half3 refractView : TEXCOORD9;
		half3 refractNormal : TEXCOORD10;
		float3 refractedPos : TEXCOORD11;
#endif

		UNITY_VERTEX_INPUT_INSTANCE_ID
			UNITY_VERTEX_OUTPUT_STEREO
	};

	float3 ObjSpaceViewDir(float4 v)
	{
		float3 objSpaceCameraPos = mul(UNITY_MATRIX_I_M, float4(GetCameraRelativePositionWS(_WorldSpaceCameraPos), 1)).xyz;
		return objSpaceCameraPos - v.xyz;
	}

	inline float4 ComputeNonStereoScreenPos(float4 pos) {
		float4 o = pos * 0.5f;
		o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
		o.zw = pos.zw;
		return o;
	}

	inline float4 ComputeScreenPos(float4 pos) {
		float4 o = ComputeNonStereoScreenPos(pos);
#if defined(UNITY_SINGLE_PASS_STEREO)
		o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
#endif
		return o;
	}

	float3 GetWorldSpacePositionFromDepth(float2 uv, float deviceDepth)
	{
		float4 positionCS = float4(uv * 2.0 - 1.0, deviceDepth, 1.0);
#if UNITY_UV_STARTS_AT_TOP
		positionCS.y = -positionCS.y;
#endif
		float4 hpositionWS = mul(UNITY_MATRIX_I_VP, positionCS);
		return hpositionWS.xyz / hpositionWS.w;
	}

	inline float4 ComputeGrabScreenPos(float4 pos) {
#if UNITY_UV_STARTS_AT_TOP
		float scale = -1.0;
#else
		float scale = 1.0;
#endif
		float4 o = pos * 0.5f;
		o.xy = float2(o.x, o.y * scale) + o.w;
#ifdef UNITY_SINGLE_PASS_STEREO
		o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
#endif
		o.zw = pos.zw;
		return o;
	}

	v2f vert(appdata v)
	{
		v2f o;

		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_TRANSFER_INSTANCE_ID(v, o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		float2 offset = 0;
#ifdef USE_HEIGHT
		offset = _Time.xx * _HeightUVScrollDistort.xy;
#endif

#ifdef _EMISSION
		o.mainUV = TRANSFORM_TEX(v.uv.xy, _MainTex) + offset;
#endif

#ifdef _FLIPBOOK_BLENDING
		o.uv.xy = TRANSFORM_TEX(v.uv, _NormalTex) + offset;
		o.uv.zw = TRANSFORM_TEX(v.texcoordBlendFrame.xy, _NormalTex) + offset;
		o.blend = v.texcoordBlendFrame.z;

#else
		o.uv.xy = TRANSFORM_TEX(v.uv, _NormalTex) + offset;
#endif

#ifdef USE_HEIGHT
		float4 uv2 = float4(TRANSFORM_TEX(v.uv, _HeightTex) + offset, 0, 0);
		float4 tex = tex2Dlod(_HeightTex, uv2);
		half3 norm = normalize(v.normal);
		v.vertex.xyz += norm * _Height * tex - norm * _Height / 2;
#endif

#ifdef USE_CUTOUT
		o.uvCutout = TRANSFORM_TEX(v.uv, _CutoutTex) + offset;
#endif

		o.vertex = TransformObjectToHClip(v.vertex.xyz);
		o.color = v.color;


		o.uvgrab = ComputeGrabScreenPos(o.vertex);

#ifdef USE_REFRACTIVE
		float3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
		float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
		o.uvgrab.xy += refract(normalize(mul(rotation, ObjSpaceViewDir(v.vertex))), 0, _RefractiveStrength) * v.color.a * v.color.a;
#endif

#if defined (_FADING_ON)
		o.screenPos = ComputeScreenPos(o.vertex);
#endif

#ifdef USE_FRESNEL
#if  defined (USE_HEIGHT)
		o.localPos = v.vertex;
		o.viewDir = normalize(ObjSpaceViewDir(v.vertex));
#else
		o.fresnel = (_FresnelInvert - abs(dot(normalize(v.normal), normalize(ObjSpaceViewDir(v.vertex)))));
		o.fresnel = pow(o.fresnel, _FresnelPow);
		o.fresnel = saturate(_FresnelR0 + (1.0 - _FresnelR0) * o.fresnel);
#endif
#endif

		return o;
	}

	half4 frag(v2f i) : SV_Target
	{

		UNITY_SETUP_INSTANCE_ID(i);


#ifdef _FLIPBOOK_BLENDING
	half4 dist1 = tex2D(_NormalTex, i.uv.xy);
	half4 dist2 = tex2D(_NormalTex, i.uv.zw);
	half3 dist = UnpackNormal(lerp(dist1, dist2, i.blend));
#else
	half3 dist = UnpackNormal(tex2D(_NormalTex, i.uv));
#endif


#ifdef USE_ALPHA_CLIPING
	half alphaBump = saturate((dot(abs(dist.rg), 0.5) - 0.00392) * _AlphaClip);
#endif

#if defined (_FADING_ON)  
	float depth = SampleCameraDepth(i.screenPos.xy / i.screenPos.w);
	float sceneZ = LinearEyeDepth(depth, _ZBufferParams);
	float partZ = i.screenPos.w;
	half fade = saturate(_InvFade * (sceneZ - partZ));
	half fadeStep = step(0.001, _InvFade);
	i.color.a *= lerp(1, fade, step(0.001, _InvFade));
#endif

	half2 offset = dist.rg * UNITY_ACCESS_INSTANCED_PROP(_Distortion_arr, _Distortion) * 0.0015 * i.color.a;

	half3 fresnelCol = 0;
#ifdef USE_FRESNEL

#if  defined (USE_HEIGHT)
#ifdef UNITY_UV_STARTS_AT_TOP
	half3 n = normalize(cross(ddx(i.localPos.xyz), ddy(i.localPos.xyz) * _ProjectionParams.x));
#else
	half3 n = normalize(cross(ddx(i.localPos.xyz), -ddy(i.localPos.xyz) * _ProjectionParams.x));
#endif
	half fresnel = (_FresnelInvert - dot(n, i.viewDir));
	fresnel = pow(fresnel, _FresnelPow);
	fresnel = saturate(_FresnelR0 + (1.0 - _FresnelR0) * fresnel);
	offset += fresnel * 0.002 * _FresnelDistort * dist.rg;
	fresnelCol = _FresnelColor * fresnel * abs(dist.r + dist.g) * 2 * i.color.rgb * i.color.a;
#else
	offset += i.fresnel * 0.002 * _FresnelDistort * dist.rg;
	fresnelCol = _FresnelColor * i.fresnel * abs(dist.r + dist.g) * 2 * i.color.rgb * i.color.a;
#endif

#endif

	half4 cutoutCol = 0;
	cutoutCol.a = 1;
#ifdef USE_CUTOUT
	half cutout = UNITY_ACCESS_INSTANCED_PROP(_Cutout_arr, _Cutout);
	cutout = i.color.a - cutout;
	half cutoutAlpha = tex2D(_CutoutTex, i.uvCutout).r - (dist.r + dist.g) / 10;
	half alpha = step(0, (cutout - cutoutAlpha));
	half alpha2 = step(0, (cutout - cutoutAlpha + _CutoutThreshold));
	cutoutCol.rgb = _CutoutColor * saturate(alpha2 - alpha);
	cutoutCol.a = saturate(alpha2 * pow(cutout, 0.2));
	
#endif

#ifdef USE_ALPHA_CLIPING
	offset *= alphaBump;
#endif
//
//#ifdef USE_REFRACTIVE
//	float3 refractedRay = (refract(-(i.refractView), (i.refractNormal * 4), _RefractiveStrength * 4));
//	float4 refractedClipPos = mul(UNITY_MATRIX_VP, float4(i.refractedPos + (refractedRay), 1.0));
//	float4 refractionScreenPos = ComputeGrabScreenPos(refractedClipPos);
//	i.uvgrab = lerp(i.uvgrab, refractionScreenPos, i.color.a);
//#endif


	half3 fogColor;
	half3 fogOpacity;
	PositionInputs posInput = GetPositionInput(i.vertex.xy, _ScreenSize.zw, i.vertex.z, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
	EvaluateAtmosphericScattering(posInput, 1, fogColor, fogOpacity);

	i.uvgrab.xy = offset * i.color.a + i.uvgrab.xy;
	half4 grabColor = float4(SampleCameraColor(i.uvgrab.xy / i.uvgrab.w).xyz, 1);
	half4 result = 1;
	half4 mainCol = UNITY_ACCESS_INSTANCED_PROP(_MainColor_arr, _MainColor);
	result.rgb = grabColor.rgb * lerp(float3(1, 1, 1), mainCol.rgb, i.color.a) + fresnelCol.rgb * grabColor.rgb * (1 - fogOpacity.x) + cutoutCol.rgb * (1 - fogOpacity.x);

#ifdef _EMISSION
	half4 tintCol = UNITY_ACCESS_INSTANCED_PROP(_TintColor_arr, _TintColor);
	half4 emissionCol = tex2D(_MainTex, i.mainUV + offset * _TintDistortion);
	emissionCol.rgb *= emissionCol.a * tintCol.rgb * i.color.a * tintCol.a ;
	result.rgb += emissionCol.rgb * (1 - fogOpacity.x);
	
#endif
	result.a = lerp(saturate(dot(fresnelCol, 0.33) * 10) * _FresnelColor.a, mainCol.a , mainCol.a) * cutoutCol.a * (1 - fogOpacity.x);
#ifdef DISTORT_ON
	result.a *= i.color.a;
#endif
#ifdef USE_ALPHA_CLIPING
	result.a *= alphaBump;
#endif

	result.a = saturate(result.a);

	return result;
	}

		ENDHLSL
	}

	}
		CustomEditor "RFX4_UberDistortionGUI"
}