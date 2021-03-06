__kernel void convolve(
	const __global float *in, 		// W*H input images
	__constant float *filt, 		// K*K filter kernel
	__global float *out, 			// W*H output images
	const int K,				// filter resolution
        const float pBias) 			// constant offset/bias
{
	// get pixel position
        const int W = get_global_size(0);
        const int H = get_global_size(1);
	
	// get image resolution
	const int x = get_global_id(0); 
	const int y = get_global_id(1);

	float sum = 0;
	int c = 0;

	// loop over rows
	for (int r = 0, r < K, r++) 
	{ 
		// loop over columns
		// only in OpenCL 2.0
		__attribute__ ((opencl unroll hint(2)))
		for(c = 0, c < K, c++)
		{
			sum += filt[r*K+c]*in[((y+r)*W+x)+c];
		}
	}
	out[y*W+x] = sum + pBias;
}
