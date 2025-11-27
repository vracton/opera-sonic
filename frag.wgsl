struct FragmentUniforms {
	mainColor : vec4<f32>,
	secColor : vec4<f32>,
	time : f32,
	picker : vec2<f32>,
	resolution : vec2<f32>,
	flags : u32,
};

@group(0) @binding(0) var<uniform> fragmentUniforms : FragmentUniforms;

@group(1) @binding(1) var audioTex : texture_2d<f32>;
@group(1) @binding(2) var audioSampler : sampler;

// Shader parameters
const SPEED: f32 = 0.7;
const CSPEED: f32 = 0.3;
const TSPEED: f32 = 0.5;
const SMEAR: f32 = 1.0;
const NUM: f32 = 15.0;
const BASS: f32 = 0.2;
const BRIGHTNESS: f32 = 0.02;
const JUICE: f32 = 1.0;
const FLASH: f32 = 2.0;
const NOISE: f32 = 0.4;//should be 0.2

//White noise (2D in, 1D out)
fn w1(p: vec2<f32>) -> f32 {
    let a = 12.9898;
    let b = 78.233;
    let c = 43758.5453;
    return fract(sin(dot(p, vec2<f32>(a, b))) * c);
}

//Audio-reactive FFT function (keeping existing method)
fn FFT(f: f32, t: f32) -> f32 {
    let amp = textureSample(audioTex, audioSampler, vec2<f32>(f, t)).r;
    return  pow(amp, 1.0 - 0.8 * f);
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>, 
@location(0) texCoord: vec2<f32>) -> @location(0) vec4<f32> {
    
    //Animation time
    let t = SPEED * fragmentUniforms.time;

    let n = 1.0 - NOISE * ((w1(fragCoord.xy)+t)%1);
    //Raymarch depth
    var z = -n;
    //Step distance
    var d = 0.0;
    
    let ray = normalize(vec3<f32>(2.0 * fragCoord.xy, 0.0) - fragmentUniforms.resolution.xyy);
    var col = vec3<f32>(0.0);
    
    for(var i: f32 = 0.0; i < NUM; i += 1.0) {
        //Sample point (from ray direction)
        var p = z * ray;
        //Move camera back 6 units
        p.z += 5.25;
        
        //Distance to center
        let len = length(p);
        
        //Rotation axis
        var axe = vec3<f32>(0.0, 2.0, 4.0) + vec3<f32>(0.0, 0.1, 0.2) * sin(TSPEED * t * 0.1) + TSPEED * (t + .1*n);
        axe = normalize(cos(axe));
        
        //Rotated coordinates
        var r = axe * dot(axe, p) - cross(axe, p);
        
        //Turbulence loop
        for(var f: f32 = 0.6; f < 4.0; f += 1.0) {
            r += sin(r * f + t).yzx / f;
        }
        
        //Sample FFT
        let freq = sin(r.y * 6.0 + fragmentUniforms.time) * 0.5 + 0.5;
        let temp = min(d * 5.0, 1.0);
        let spec = FFT(freq, temp);
        //Saturation fluctuation
        let sat = 0.2+fragmentUniforms.picker.y;
        //0.2 + (0.4 + 0.5 * sin(0.6 * CSPEED * fragmentUniforms.time + r.y/len) + spec) * JUICE;
        
        //Distance to sphere
        let sphere = len - 3.0 - clamp(spec, 0.0, 0.45);
        d = 0.1 * length(vec2(sphere, r.x));
        //Step forward
        z += d * 3;
        //Color hue in radians
        let hue = d * 2.0 + z * 0.3 + fragmentUniforms.picker.x * 4.0 + 3.0 * spec;
        //Add color sample
        col += (cos(hue + sat * vec3<f32>(-1.0, 0.0, 1.0)) + 1.0) / (d * 1);
    }
    //Output color
    col = col / NUM * BRIGHTNESS;
    col = tanh(clamp(col, vec3<f32>(0.0), vec3<f32>(4.0)));
    return vec4<f32>(col, 1.0);
}