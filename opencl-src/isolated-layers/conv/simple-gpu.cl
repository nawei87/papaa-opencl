__kernel void convolve(
	const __global float *in, 		// W*H input images
	__constant float *filt, 		// K*K filter kernel
	__global float *out, 			// W*H output images
	const int K,				// filter resolution
	const int K1,				// filter resolution
	const int K2,				// filter resolution
        const __global float *pBias) 			// constant offset/bias
{
	// get pixel position
        const int W = get_global_size(0);
        const int H = get_global_size(1);
	
	// get image resolution
	const int x = get_global_id(0); 
	const int y = get_global_id(1);

	// allocate local RAM for storing input pixels
	__local float in_local[28*28];

	// load data into the local RAM
	in_local[x*W+y] = in[x*W+y];
	barrier(CLK_LOCAL_MEM_FENCE);

	float sum = 0;
	int c = 0;

	// loop over rows
	for (int r = 0; r < K; r++) 
	{ 
		// loop over columns
		for(c = 0;c < K; c++)
		{
			sum += filt[r*K+c]*in_local[((y+r)*W+x)+c];
		}
	}
	out[y*W+x] = sum + *pBias;
}
