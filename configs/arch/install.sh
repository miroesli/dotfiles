#!/bin/bash
configs=(alacritty dunst i3 redshift polybar picom nvim joplin zathura)
dots=(.zshrc .gitconfig)

for config in "${configs[@]}"
do
	cp -r .config/$config ~/.config
done
for dot in "${dots[@]}"
do
	cp $dot ~
done

echo done
