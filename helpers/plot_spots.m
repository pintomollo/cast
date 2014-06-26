function hgroup = plot_spots(h, spots, color)

  if (nargin == 1)
    spots = h;
    h = gca;
    color = 'r';
  elseif (nargin == 2)
    if (ischar(spots))
      color = spots;
      spots = h;
      h = gca;
    end
  end

  if (iscell(spots))
    spots = spots{1};
  end

  if (strncmp(get(h, 'Type'), 'hggroup',7))
    hgroup = h;
  else
    hgroup = hggroup('Parent', h);
  end

  haxes = get(hgroup, 'Parent');

  status = get(haxes, 'NextPlot');
  set(haxes,'NextPlot', 'add');

  hrects = get(hgroup, 'Children');
  nrects = length(hrects);

  for i=1:size(spots, 1)
    pos = [spots(i, 1:2)-2*spots(i,3) 4*spots(i, [3 3])];

    if (i>nrects)
      rectangle('Position', pos, 'Curvature', [1 1], 'Parent', hgroup, 'EdgeColor', color);
    else
      set(hrects, 'Position', pos, 'EdgeColor', color);
    end
  end

  set(haxes,'NextPlot', status);

  delete(hrects(i+1:nrects))

  return;
end
