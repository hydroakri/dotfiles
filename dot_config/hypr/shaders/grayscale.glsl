precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {

    vec4 pixColor = texture2D(tex, v_texcoord);

    // Convert to grayscale using the luminance formula
    float luminance = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 grayscaleColor = vec3(luminance);

    gl_FragColor = vec4(grayscaleColor, pixColor.a);
}
