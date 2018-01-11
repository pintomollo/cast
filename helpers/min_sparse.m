function [mins, indxs] = min_sparse(mat)
% MIN_SPARSE returns the minimum value among the assigned values of a sparse matrix,
% i.e. it ignores the 0's of the sparse matrix.
%
%   MINS = MIN_SPARSE(MAT) returns the MINS values, column-wise, from the sparse matrix
%   MAT. Note that if no value has been assigned to a column, the corresponding MINS
%   value will be Inf.
%
%   [MINS, INDXS] = MIN_SPARSE(MAT) returns in addition the INDXS of the MINS values.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 10.04.2015

  % Get the size of the matrix
  ncols = size(mat, 2);

  % If we have several columns to handle, do it recursively
  if (ncols > 1)
    mins = NaN(1, ncols);
    indxs = mins;

    for i=1:ncols
      [mins(i), indxs(i)] = min_sparse(mat(:,i));
    end
  else

    % Otherwise, get the assigned values
    [indxi, indxj, vals] = get_sparse_data_mex(mat);

    % Handle no values at all
    if (isempty(vals))
      mins = Inf;
      indxs = 1;

    else
      % Simply call the min function itself
      [mins, indx] = min(vals);

      % And retrieve the actual index value
      indxs = indxi(indx);
    end
  end

  return;
end
