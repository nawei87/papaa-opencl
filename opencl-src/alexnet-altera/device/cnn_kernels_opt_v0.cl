//FIXME: If taking trained model from Lasagne, the conv filters flipped by default.
//Either perform flip here OR disable flip during training !!!
// 3D convolution + ReLU activation kernel
__kernel void conv_3d_relu(
	const __global float * restrict p_maps,
	const __global float * restrict p_weights,
	const __global float * restrict p_bias,
	__global float * restrict p_output,
	const unsigned int K,
	const unsigned int stride,
	const unsigned int no_inputs) {

	const int x = get_global_id(0); 
	const int y = get_global_id(1);
	const int z = get_global_id(2);
	
	const int out_width  = get_global_size(0);
	const int out_height = get_global_size(1);
	const int in_width = out_width + K - 1;
	const int in_height = out_height + K - 1;

	// Assume horizontal and vertical strides are same. Generally this is the case.
	// Same assumptions holds good for kernel dimensions as well.
	int wstart = x * stride;
	int hstart = y * stride;
	int wend = wstart + K;
	int hend = hstart + K;

	const int filter_start = z * K * K * no_inputs;
	int F = (int)K;
	float pix, w;
	float4 sum4 = 0.0;
	float zero = 0.0;
	float sum = 0.0;
	#pragma unroll 2
	for(unsigned int map = 0; map < no_inputs; map++) {
		#pragma unroll 3
		for(unsigned int r = 0; r < K; r++) {
			const int fstart = filter_start + map * K * K + r * K;
			const int map_start = ((map * in_height) + hstart + r) * in_width + wstart;
			int c = 0;
			int c4 = 0;
			// vector ops
			while(c <= F-4) {
				float4 filter4 = vload4(c4, p_weights + fstart);
				float4 data4 = vload4(c4, p_maps + map_start);
				sum4 += filter4 * data4;
				c += 4;
				c4++;
			}
			// remaining columns
			for(int c1 = c; c1 < K; c1++) {
				sum4.x += p_weights[fstart + c1] * p_maps[map_start + c1];
			}

		}
	}
	sum = sum4.x + sum4.y + sum4.z + sum4.w + p_bias[z];
	p_output[((z*out_height) + y) * out_width + x] = fmax(zero, sum);
}
__kernel void maxpool_3d(
	const __global float * restrict pInput,
	__global float * restrict pOutput,
	const int iWidth,
	const int iHeight,
	const int nPoolsize,
	const int nStride) {

	const int x = get_global_id(0); 
	const int y = get_global_id(1);
	const int z = get_global_id(2);
	
	const int oWidth  = get_global_size(0);
	const int oHeight = get_global_size(1);

	float maxval = -3.402823e+37;
	int hstart = y*nStride;
	int wstart = x*nStride;
	int hend = hstart+nPoolsize;
	int wend = wstart+nPoolsize;
	for(unsigned int r = hstart; r < hend; r++) {
		for(unsigned int c = wstart; c < wend; c++) {
			unsigned int idx = z*iHeight*iWidth + r * iWidth + c;
			maxval = fmax(maxval, pInput[idx]);
		}
	}
        pOutput[(((z*oHeight)+y)*oWidth)+x] = maxval;
}


// Perceptron layer + conditional ReLU activation
__kernel void fc_layer_relu(
	const __global float * restrict pInput,
	const __global float * restrict pWeights,
	__global float * restrict pOutput,
	const int nInputs,
	const __global float * restrict pBias,
	const unsigned char act) {

	const int x = get_global_id(0);
	const int idxstart = x*nInputs;
	float sum = 0;
	float zero = 0;
	#pragma unroll 32
	for (int i = 0; i <nInputs; i++) 
	{
		sum += pWeights[idxstart+i]*pInput[i];
	}
	sum += pBias[x];
	if(act == 1) {
		pOutput[x] = fmax(zero, sum);
	} else {
		pOutput[x] = sum;
	}
}

// Need to do piecewise linear approximation for exp(x)
// Just implementing exp here. Normalizing probalities to be carried out on the host.
__attribute__((max_work_group_size(1000)))
__kernel void softmax(
	__global float * pdata) {

	//__local float sum, prob[1000];
	const int x = get_global_id(0);
	pdata[x] = exp(pdata[x]);

	/*barrier(CLK_LOCAL_MEM_FENCE);
	if(x == 0) {
		sum = 0;
		for(int i=0; i< get_local_size(0); i++) {
			sum += prob[i];
		}
	}
	barrier(CLK_LOCAL_MEM_FENCE);

	pdata[x] = prob[x]/sum;
	pdata[x] = prob[x];	*/
}


__kernel void batch_norm_layer(
	__global float * restrict pMaps,
	// TODO: use local memory for scale and offset
	__global float * restrict pScale,
	__global float * restrict pOffset,
	__global float * restrict pOutput) {
	
	const int map_no = get_global_id(2);
	const int row_no = get_global_id(1);
	const int col_no = get_global_id(0);
	const int W = get_global_size(0);
	const int H = get_global_size(1);
	float norm_pix;
	const int pos = map_no*W*H + row_no*W + col_no;
	norm_pix = pMaps[pos] * pScale[map_no] + pOffset[map_no];
	pOutput[pos] = norm_pix;
}
