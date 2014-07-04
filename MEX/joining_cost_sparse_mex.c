#include <math.h> // Needed for the ceil() prototype
#include "mex.h"

// Define few opeartions useful to compute the costs

#define __MAX__(A, B)     ((A)>=(B)? (A) : (B))
#define __SQR__(A)        ((A) * (A))
#define __WGT__(A)        ((A)>=1? (A) : (1/((A)*(A))))

/// See paper "A Fast, Compact Approximation of the Exponential Function".
/// 2x to 9x faster than exp(x)!
/// Can be off by about +-4% in the range -100 to 100.
double fast_exp(double y) {
  double d;
  *((int*)(&d) + 0) = 0;
  *((int*)(&d) + 1) = (int)(1512775 * y + 1072632447);
  return d;
}

// Retrieve the signal from a gaussian spot in a cell array of spot matrices
double get_signal(int frame_indx, int spot_indx, const mxArray *spots) {

  mwSize m, n;
  const mxArray *cell_element_ptr;
  double *spot;
  double signal;

  signal = 0;
  if (spot_indx >= 0) {

    // Get the corresponding cell content
    cell_element_ptr = mxGetCell(spots, frame_indx);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    // Compute the signal as the integral under the 2D gaussian
    if (spot_indx < m && n > 3) {
      spot  = mxGetPr(cell_element_ptr);
      signal = __SQR__(spot[spot_indx + 2*m]) * spot[spot_indx + 3*m];
    }
  }

  return signal;
}

// Retrives the signal of the spot next in the track of the current spot
double get_next_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize mmax, m, n;
  mwIndex i,j, parent_indx, frame_indx;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frames;

  mmax = mxGetNumberOfElements(links);

  // Look for a link that points towards us, in all consecutive frames
  parent_indx = -1;
  for (j=frame+1; j<mmax; j++) {
    cell_element_ptr = mxGetCell(links, j);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    curr_indx  = mxGetPr(cell_element_ptr);
    prev_indx = curr_indx + m;
    frames = prev_indx + m;

    // Need to check each individual link
    for (i=0; i<m; i++) {
      if (frames[i] == frame + 1 && prev_indx[i] == spot_indx + 1) {
        parent_indx = curr_indx[i] - 1;
        frame_indx = j;
        break;
      }
    }

    // When found, stop
    if (parent_indx != -1) {
      break;
    }
  }

  // Retrives the corresponding signal
  return get_signal(frame_indx, parent_indx, spots);
}

// Get the signal of the previous spot in the track of the current spot
double get_prev_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize m, n;
  mwIndex i, child_indx, child_frame;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frame_indx;

  cell_element_ptr = mxGetCell(links, frame);
  m  = mxGetM(cell_element_ptr);
  n  = mxGetN(cell_element_ptr);

  // Here it's easier as we know that our spot must point towards its predecessor
  curr_indx  = mxGetPr(cell_element_ptr);
  prev_indx = curr_indx + m;
  frame_indx = prev_indx + m;

  // So simply find the link of the current spot
  child_indx = -1;
  child_frame = 0;
  for (i=0; i<m; i++) {
    if (curr_indx[i] == spot_indx + 1) {
      child_indx = prev_indx[i] - 1;
      child_frame = frame_indx[i] - 1;

      break;
    }
  }

  // Retrieve the signal of the corresponding spot
  return get_signal(child_frame, child_indx, spots);
}

// The main of the MATLAB interface
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  // Declare variable
  mwSize m1,n1, m2, n2;
  mwSize nzmax, nzstep;
  mwIndex *irs,*jcs,i,j, count, *irs2, *jcs2;
  const mxArray *spots, *links;
  double *x1,*y1,*t1,*x2,*y2,*t2,*rs,*i1,*i2, *rs2;
  double dist, dist2, thresh, thresh2, signal1, signal2, signal_prev;
  double weight, alt_weight, alt_move;
  bool is_test;

  // Check for proper number of input and output arguments
  if (nrhs == 4) {
    is_test = true;
  } else if (nrhs == 7) {
    is_test = false;
  } else {
    mexErrMsgIdAndTxt( "MATLAB:joining_cost_sparse_mex:invalidNumInputs",
        "Four or seven input arguments required.");
  }

  // Check data type of input argument
  if (!(mxIsDouble(prhs[0]) && mxIsDouble(prhs[1]) && mxIsDouble(prhs[2]))){
    mexErrMsgIdAndTxt( "MATLAB:joining_cost_sparse_mex:inputNotDouble",
        "Input arguments (1,2,3) must be of type double.");
  }
  if (!is_test && !(mxIsCell(prhs[5]) && mxIsCell(prhs[6]))) {
    mexErrMsgIdAndTxt( "MATLAB:joining_cost_sparse_mex:inputNotCell",
        "Input arguments (6, 7) must be of type cell.");
  }

  // Get the size and pointers to input data
  m1  = mxGetM(prhs[0]);
  n1  = mxGetN(prhs[0]);

  // Get the different pointers to the various columns of data
  x1  = mxGetPr(prhs[0]);
  y1  = x1 + m1;
  i1  = x1 + (n1-2)*m1;
  t1  = x1 + (n1-1)*m1;

  // Same for the other matrix
  m2  = mxGetM(prhs[1]);
  n2  = mxGetN(prhs[1]);

  x2  = mxGetPr(prhs[1]);
  y2  = x2 + m2;
  i2  = x2 + (n2-2)*m2;
  t2  = x2 + (n2-1)*m2;

  // Get the two thresholds
  thresh = __SQR__(mxGetScalar(prhs[2]));
  thresh2 = mxGetScalar(prhs[3]);

  // A guess on the number of elements needed
  nzmax=(mwSize)ceil((double)m1*(double)m2*0.1);
  nzstep=(mwSize)__MAX__(ceil((double)nzmax*0.25),1);

  // Here we only check if they could interact
  if (is_test) {

    // Returns a boolean list of interactions
    plhs[0] = mxCreateDoubleMatrix(1,m2,mxREAL);
    rs  = mxGetPr(plhs[0]);

    for (i = 0; i < m2; i++) {
      for (j = 0; j < m1; j++) {
        dist2 = t2[i]-t1[j];

        // The distance
        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        // Check if possible
        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {
          rs[i] = true;
          break;
        }
      }
    }

  // Here we compute the actual costs
  } else {

    // The average movement, for the alternative costs
    alt_move = mxGetScalar(prhs[4]);
    alt_move = -__SQR__(alt_move);

    // The list of all information, to retrieve the intensitites
    spots = prhs[5];
    links = prhs[6];

    // Prepare the output
    plhs[0] = mxCreateSparse(m1,m2,nzmax,false);
    rs  = mxGetPr(plhs[0]);
    irs = mxGetIr(plhs[0]);
    jcs = mxGetJc(plhs[0]);

    // And the alternative weights
    plhs[1] = mxCreateDoubleMatrix(m2, 1,mxREAL);
    rs2  = mxGetPr(plhs[1]);

    // Need to count the number of elements inserted in the sparse matrix
    count = 0;
    for (i = 0; i < m2; i++) {

      // The number of elements up to the current column
      jcs[i] = count;

      // The current and previous signals
      signal2 = get_signal(t2[i]-1, i2[i]-1, spots);
      signal_prev = get_prev_signal(t2[i]-1, i2[i]-1, spots, links);

      // The alternative weight
      alt_weight = __WGT__(signal2 / signal_prev);
      rs2[i] = -fast_exp(alt_move*alt_weight);

      // Now the actual weights
      for (j = 0; j < m1; j++) {
        dist2 = t2[i]-t1[j];

        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        // But only if it passes the threshold
        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {

          // Here we might need to increase the number of elements in the matrix
          if (count >= nzmax){
            nzmax += nzstep;

            mxSetNzmax(plhs[0], nzmax);
            mxSetPr(plhs[0], mxRealloc(rs, nzmax*sizeof(double)));
            mxSetIr(plhs[0], mxRealloc(irs, nzmax*sizeof(mwIndex)));

            rs  = mxGetPr(plhs[0]);
            irs = mxGetIr(plhs[0]);
          }

          // Get the other signal
          signal1 = get_signal(t1[j]-1, i1[j]-1, spots);

          // The weight
          weight = __WGT__(signal2 / (signal1 + signal_prev));

          // Store it in the matrix
          rs[count] = -fast_exp(-dist*weight);
          irs[count] = j;

          count++;
        }
      }
    }

    // Requried to finalize the sparse matrix
    jcs[m2] = count;
  }
}
