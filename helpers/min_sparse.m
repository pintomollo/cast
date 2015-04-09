function [mins, indxs] = min_sparse(mat)

  ncols = size(mat, 2);
  if (ncols > 1)
    mins = NaN(1, ncols);
    indxs = mins;

    for i=1:ncols
      [mins(i), indxs(i)] = min_sparse(mat(:,i));
    end
  else
    [indxi, indxj, vals] = get_sparse_data_mex(mat);
    if (isempty(vals))
      mins = Inf;
      indxs = 1;
    else
      [mins, indx] = min(vals);
      indxs = indxi(indx);
    end
  end

  return;
end
