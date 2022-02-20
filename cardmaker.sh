#! /usr/bin/env bash
# ***** CARD MAKER *****
# Uses two webcams taped into a big white box to photograph the Garstang's card catalogues, card by card.

# Copyright © 2021 Joel Sams
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# Quickly bodged together by Joel Sams: hsjsams@liverpool.ac.uk
# Dependencies: bash, video4linux2, imagemagick, ffmpeg, sxiv.  I think that's it.
# Documentation: None yet.  Take very regular backups, because at some point you will probably write over some previous scans.



# INITIAL VARIABLES:

# Setting an initial well-formed card name
cardnumber=99999 # initial card number set way too high, for safety.
prefix='UNNUMBERED.'
leading_zeros=5
card_name=$(format_card_name $cardnumber $prefix $leading_zeros)
filetype='jpg'

# Colors:
nc='\033[0m' # No Color           
yellow='\033[1;33m'


# FUNCTIONS:
function welcome {
    clear
    echo "LET'S SCAN SOME CARDS!"
    echo
    echo "First some setup..."
}

function format_card_name {
    # takes an integer, a prefix, and a number of leading zeros, and
    # returns the integer formatted according to the Garstang's
    # accession numbering scheme.
    # e.g. format_card_name 2 'E' 5 returns E00002
    cardlabel=$(printf "$2%0$3d" $1)
    echo "$cardlabel"
}

function increment_card {
    ((cardnumber++))
    card_name=$(format_card_name $cardnumber $prefix $leading_zeros)
}

function decrement_card {
    ((cardnumber--))
    card_name=$(format_card_name $cardnumber $prefix $leading_zeros)
}

function okay_p {
    # Checks if something's okay: any answer apart from "y" is not okay.
    read answer
    if [ "$answer" != "y" ]; then
	echo "nope"
    else
	echo "yep"
    fi
}

function set_dev_videonums {
    # set the /dev/video numbers for the two webcams
    echo
    echo "Available video streams:"
    ls /dev/video*
    echo
    echo "What is the /dev/video number for the top webcam?"
    read topcam
    topcam="/dev/video$topcam"
    echo "What is the /dev/video number for the bottom webcam?"
    read bottomcam
    bottomcam="/dev/video$bottomcam"
    echo "Top cam stream accessible at:    $topcam"
    echo "Bottom cam stream accessible at: $bottomcam"
    echo -n "Correct? (y/n)"
    if [ $(echo $(okay_p)) = "nope" ]; then
	set_dev_videonums
    fi
}

function copy_forward {
    echo "copying forward..."
    oldcardfile="$card_name.$filetype"
    increment_card
    cardfile="$card_name.$filetype"
    cp $oldcardfile $cardfile
    sxiv "$cardfile"
    select_scan_options
}

function set_next_cardnumber {
    # set the next cardnumber to scan
    echo
    echo "Enter the number of the next card to scan, minus any prefix or leading zeros (e.g. E0001 = 1)"
    read cardnumber
    card_name=$(format_card_name $cardnumber $prefix $leading_zeros)
    echo "Next card number is: $card_name"
    # echo -n "Correct? (y/n)"
    # if [ $(echo $(okay_p)) = "nope" ]; then
    # 	set_next_cardnumber
    # fi    
}

function set_new_prefix {
    # set the next cardnumber to scan
    echo
    echo "Enter the prefix to use:"
    read prefix
    card_name=$(format_card_name $cardnumber $prefix $leading_zeros)
    select_scan_options
}

function print_menu {
    echo
    printf "ARE YOU SCANNING:   $yellow$card_name$nc  ?\n"
    echo "-------------------------------------------"
    echo
    echo "y   scan this card"
    echo "r   redo previous card"
    echo "a   append an extra card to the previous card"
    echo "A   append an extra card to THIS card number"
    echo "n   set new card number"
    echo "d   display current card"
    echo "p   set new prefix"
    echo "f   increment card number"
    echo "d   decrement card number"
    echo "C   copy this card forward as the next card"
    echo "Z  quit"
    echo
}

function select_scan_options {
    clear
    print_menu
    read -n 1 answer
    if [ $answer = "y" ]; then
	scan_this_card
    elif [ $answer = "r" ]; then
	redo_card
    elif [ $answer = "a" ]; then
	append_card
    elif [ $answer = "A" ]; then
	increment_card
	append_card
    elif [ $answer = "n" ]; then
	set_new_card_number
    elif [ $answer = "d" ]; then
	display_current_card
    elif [ $answer = "p" ]; then
	set_new_prefix
    elif [ $answer = "Z" ]; then
	get_out
    elif [ $answer = "f" ]; then
	increment_card
	select_scan_options
    elif [ $answer = "b" ]; then
	decrement_card
	select_scan_options
    elif [ $answer = "C" ]; then
	copy_forward
	select_scan_options
    elif [ $answer = "Z" ]; then
	get_out
    else
	select_scan_options
    fi
}

function display_current_card {
    sxiv "$card_name.$filetype"
    select_scan_options
}

function scan_card {
    # takes a picture from each webcam and montages them together as a temporary file: tempcard.jpg
    echo "front..."
    ffmpeg -loglevel -8 -f video4linux2 -s 2304x1536 -i $topcam top.jpg
    echo "back..."
    ffmpeg -loglevel -8 -f video4linux2 -s 2304x1536 -i $bottomcam bottom.jpg
    # wait
    echo "montaging..."
    montage top.jpg bottom.jpg -geometry +0+0 -tile 2x1 tempcard.jpg
    rm top.jpg
    rm bottom.jpg
}

function scan_this_card {
    echo "-------------------------------------------"
    echo "scanning card $card_name"
    scan_card
    cardfile="$card_name.$filetype"
    mv 'tempcard.jpg' $cardfile
    sxiv -s f $cardfile
    increment_card
    select_scan_options
}

function redo_card {
    decrement_card
    echo "-------------------------------------------"
    echo "redoing card $card_name"
    cardfile="$card_name.$filetype"
    rm $cardfile
    scan_this_card
}

function append_card {
    decrement_card
    echo "-------------------------------------------"
    echo "appending to card $card_name"
    scan_card
    cardfile="$card_name.$filetype"
    montage $cardfile tempcard.jpg -geometry +0+0 -tile 1x2 tempmontcard.jpg
    sxiv -s f tempmontcard.jpg
    echo "keep it appended? (y/n)"
    if [ $(echo $(okay_p)) = "yep" ]; then
	mv tempmontcard.jpg $cardfile
    fi
    rm tempmontcard.jpg
    rm tempcard.jpg
    increment_card
    select_scan_options
}

function set_new_card_number {
    echo "-------------------------------------------"
    echo "setting new card number"
    set_next_cardnumber
    select_scan_options
}

function get_out {
    echo "-------------------------------------------"
    echo "goodbye"
}


# 'MAIN LOOP' STARTS HERE:
welcome
set_dev_videonums
set_next_cardnumber
clear
echo "Top cam on:    $topcam"
echo "Bottom cam on: $bottomcam"
echo
select_scan_options
