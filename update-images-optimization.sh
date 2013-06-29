#/bin/bash

#############################################
#        howto: compress pictures
# You will need to install binary files first
# apt-get install aptitude
# aptitude install optipng pngcrush jpegoptim
#############################################

# protect recovery images from modding, or recovery will be broken.
mv nx-recovery /tmp/;

find . -iname '*.png' -exec optipng -o7 {} \;

for file in `find . -name "*.png"`;do
	echo $file;
	pngcrush -rem alla -reduce -brute "$file" tmp_img_file.png;
	mv -f tmp_img_file.png $file;
done;

find . -iname '*.jpg' -exec jpegoptim --force {} \;

# restore recovery images type.
mv /tmp/nx-recovery ./;

echo "done, picks optimized"

