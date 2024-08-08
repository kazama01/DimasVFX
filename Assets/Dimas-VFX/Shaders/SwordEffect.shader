Shader "Custom/Dimas/SwordEffect" {
	Properties{
		[HDR]_TintColor("Tint Color", Color) = (1,1,1,1)
		_GradientStrength("Gradient Strength", Float) = 0.5
		_TimeScale("Time Scale", Vector) = (1,1,1,1)
		_MainTex("Noise Texture", 2D) = "white" {}
		_BorderScale("Border Scale (XY) Offset (Z)", Vector) = (0.5,0.05,1,1)
	}
		Category{

		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

		SubShader{

		Pass{
		
		Blend One OneMinusSrcAlpha
		Cull Off
		Offset -1, -1
		ZWrite Off


		HLSLPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile_instancing
		#pragma target 4.6

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
		#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/AtmosphericScattering/AtmosphericScattering.hlsl"

		sampler2D _MainTex;
		float4 _TintColor;
		float4 _TimeScale;
		float4 _BorderScale;
		half _GradientStrength;

	struct appdata_t {
		float4 vertex : POSITION;
		float4 color : COLOR;
		float2 texcoord : TEXCOORD0;
		float3 normal : NORMAL;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f {
		float4 vertex : POSITION;
		float4 color : COLOR;
		float2 texcoord : TEXCOORD0;
		float4 worldPosScaled : TEXCOORD1;
		float3 normal : NORMAL;
		UNITY_VERTEX_INPUT_INSTANCE_ID
			UNITY_VERTEX_OUTPUT_STEREO
	};

	float4 _MainTex_ST;

	v2f vert(appdata_t v)
	{
		v2f o;
		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_TRANSFER_INSTANCE_ID(v, o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		o.vertex = TransformObjectToHClip(v.vertex.xyz);
		o.color = v.color;
		o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
		float3 worldPos = v.vertex * float3(length(UNITY_MATRIX_M[0].xyz), length(UNITY_MATRIX_M[1].xyz), length(UNITY_MATRIX_M[2].xyz));
		o.worldPosScaled.x = worldPos.x *  _MainTex_ST.x;
		o.worldPosScaled.y = worldPos.y *  _MainTex_ST.y;
		o.worldPosScaled.z = worldPos.z *  _MainTex_ST.x;
		o.worldPosScaled.w = worldPos.z *  _MainTex_ST.y;
		o.normal = abs(v.normal);
		return o;
	}


	half tex2DTriplanar(sampler2D tex, float2 offset, float4 worldPos, float3 normal)
	{
		half3 texColor;
		texColor.x = tex2D(tex, worldPos.zy + offset);
		texColor.y = tex2D(tex, worldPos.xw + offset);
		texColor.z = tex2D(tex, worldPos.xy + offset);
		normal = normal / (normal.x + normal.y + normal.z);
		return dot(texColor, normal);
	}

	half4 frag(v2f i) : COLOR
	{
		UNITY_SETUP_INSTANCE_ID(i);
		half mask = tex2DTriplanar(_MainTex, _Time.x * _TimeScale.xy, i.worldPosScaled, i.normal);

		half tex = tex2DTriplanar(_MainTex, _Time.x * _TimeScale.zw + mask * _BorderScale.x, i.worldPosScaled, i.normal);
		half alphaMask = tex2DTriplanar(_MainTex, 0.3 + mask * _BorderScale.y, i.worldPosScaled, i.normal);

		float4 res;
		res = i.color * pow(_TintColor, 2.2);
		res *= tex * mask;

		res = lerp(float4(0, 0, 0, 0), res, alphaMask.xxxx);
		res.rgb = pow(res.rgb, _BorderScale.w);
		
		half gray = dot(saturate(res.rgb + _GradientStrength), 0.33);
		res = float4(res.rgb, gray )* _TintColor.a;

		half3 fogColor;
		half3 fogOpacity;
		PositionInputs posInput = GetPositionInput(i.vertex.xy, _ScreenSize.zw, i.vertex.z, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
		EvaluateAtmosphericScattering(posInput, 1, fogColor, fogOpacity);
		res.rgb = res.rgb * (1 - fogOpacity) ;
		res.a = res.a * (1 - fogOpacity.x);

		return res;
	}
		ENDHLSL
	}
	}

	}
}