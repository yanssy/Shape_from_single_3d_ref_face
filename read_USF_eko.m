function [ pts,tri,rgb,x,y,z,spherical,im_mean,eyes_rgb ] = read_USF_eko( echo_path,r,c,black_eyes,talk,is_full )
%READ_USF_EKO path can be an echo file path or a whole directory for batch
if nargin<6
    is_full = 0;
end
if nargin<5
    talk = 0;
end
if nargin <4
    black_eyes = 0;
end
% f = figure;
if strcmp(echo_path(end-3:end),'.eko')
    [spherical_mean,r,c] = find_USF_spherical(echo_path);
    im_mean = find_USF_im(echo_path);
else
    try
        if echo_path(end)~='/' || echo_path(end)~='\'
            echo_path(end+1)='\';
        end
        echo_path_in = echo_path;
        im_mean = imread([echo_path 'ref_albedo.bmp']);
        load([echo_path_in 'ref_depth.mat']);
    catch
        RGB_to_XYZ = [  0.4124564 0.3575761 0.1804375;
            0.2126729 0.7151522 0.0721750;
            0.0193339 0.1191920 0.9503041];
        XYZ_to_RGB = inv(RGB_to_XYZ);
        count = zeros(r,c);
        counter = 0;
        echo_paths = getAllFiles(echo_path,1);
        spherical_mean = zeros(r,c);
        im_mean = zeros(r,c,3);
        for i=1:numel(echo_paths)
            echo_path_i = echo_paths{i};
            if ~strcmp(echo_path_i(end-3:end),'.eko')
                continue;
            end
            prev_num = num2str(str2num(echo_path_i(end-5:end-4))-1);
            prev_name = [echo_path_i(1:end-6) prev_num '.eko'];
            if (i-4)<1
                continue
            end
            if ~strcmp(echo_paths{i-4},prev_name)
                continue
            end
            [spherical,r,c] = find_USF_spherical(echo_path_i);
            valid = ~isnan(spherical);
%             spherical_mean(valid) = ...
%                 spherical_mean(valid) + ...
%                 (spherical(valid)-spherical_mean(valid))...
%                 ./count(valid);
            spherical_mean(valid) = (spherical_mean(valid).*count(valid)...
                +spherical(valid))./(count(valid)+1);
            im = double(find_USF_im(echo_path_i));
            xyz = rgb2xyz(im/255);
            im = correct(xyz,XYZ_to_RGB)*255;
%             im_mean = im_mean + (im-im_mean)/max(count(:));
%             im_mean = (im_mean*counter+im)/(counter+1);
            valid3 = repmat(valid,1,1,3);
            count3 = repmat(count,1,1,3);
            im_mean(valid3) = (im_mean(valid3).*...
                count3(valid3)+im(valid3))./(count3(valid3)+1);
            subplot(1,2,1);imshow(im/255);subplot(1,2,2);imshow(im_mean/255)
            count(valid) = count(valid) + 1;
            counter = counter+1;
            %         figure(f);
            %         imshow(im_mean)
            %         pause(0.0001);
        end
        if talk
            fprintf('Models used: %d\n', counter)
        end
        im_mean = uint8(im_mean);
        spherical_mean(count < (max(count(:)))/5 ) = NaN;
        im_mean(count3 < (max(count3(:)))/5 ) = 0;
        imwrite(im_mean,[echo_path_in 'ref_albedo.bmp']);
        save([echo_path_in 'ref_depth'],'spherical_mean');
    end
    spherical = [];
    
end

%% convert spherical to cartesian coordinated
[x,y,z] = spherical_to_cart_USF( spherical_mean,r,c );
%% clip to valid region only
valid_region = im2double(imread('D:\Drives\Google Drive\Research UCSD\Ravi\Sony SFS\datasets\USF 3D Face Data\USF Raw 3D Face Data Set\data_files\test\range2.bmp'));
valid_region(valid_region==0) = NaN;
if is_full
    valid_region(:) = 1;
end
im_mean = im2double(im_mean).*repmat(double(valid_region(end:-1:1,:)),1,1,3);

%% plot results
if talk
    figure;surf(x,y,z,im_mean,'FaceColor','interp','edgealpha',0.0);
    axis equal
end

%% output conditioning
offset = min(x(:));
pts = [ y(:)*9 z(:)*9 (x(:)-offset)*9]';
x = pts(1,:);
y = pts(2,:);
z = pts(3,:);


%% generate triangulation and rgb
if black_eyes
    eyes_small_rgb = double((im2double(imread('D:\Drives\Google Drive\Research UCSD\Ravi\Sony SFS\datasets\USF 3D Face Data\USF Raw 3D Face Data Set\data_files\test\eyes_small_mask.bmp')))~=1);
    eyes_small_rgb(eyes_small_rgb==0) = 0.1;
    im_mean = im_mean .* eyes_small_rgb;
end
eyes_rgb = (im2double(imread('D:\Drives\Google Drive\Research UCSD\Ravi\Sony SFS\datasets\USF 3D Face Data\USF Raw 3D Face Data Set\data_files\test\eyes_mask.bmp')));
eyes_rgb = (reshape(eyes_rgb,size(pts,2),3)');
pts = [x;y;z];
rgb = (reshape(im_mean,size(pts,2),3)');

tri = generate_tri_USF(1:size(im_mean,1),1:size(im_mean,2));
tri = tri(:,:)'-1;

end