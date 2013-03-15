#!/usr/bin/env ruby

# repacker.rb - Copyright (c) 2013 Maxim Kouprianov
#
# This software is provided 'as-is', without any express or
# implied warranty. In no event will the authors be held
# liable for any damages arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute
# it freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented;
#    you must not claim that you wrote the original software.
#    If you use this software in a product, an acknowledgment
#    in the product documentation would be appreciated but
#    is not required.
#
# 2. Altered source versions must be plainly marked as such,
#    and must not be misrepresented as being the original software.
#
# 3. This notice may not be removed or altered from any
#    source distribution.
#
# Author: Maxim Kouprianov <maxim@kouprianov.com>

require 'fileutils'

KITCHEN = File.expand_path(File.dirname(__FILE__))
TOOLS = KITCHEN + '/tools'

def help
    puts <<-eof
Usage:
    ./repacker.rb <boot.img> to unpack
    ./repacker.rb <boot_src> to pack
    eof
end

if ARGV.count < 1
    help
else
    filename = File.expand_path ARGV.pop
    filename_base = File.basename filename
    type = `file #{filename}`.split(' ').last

    case type

    # When argument points to .img (raw data)
    when 'data'
        dir = "boot_src.#{rand(500)}"
        FileUtils.rm_rf(dir, :secure => true) if File.exist? dir
        Dir.mkdir(dir)
        Dir.mkdir(dir + '/ramdisk')

        Dir.chdir dir do
            # Splits boot.img into a kernel and a ramdisk
            `#{TOOLS}/split_bootimg.pl #{filename}`

            Dir.chdir('ramdisk') do
                # Unpack the ramdisk
                `gunzip -c ../ramdisk.gz | cpio -i 2>/dev/null`

                # Clean volatile
                File.delete '../ramdisk.gz'
            end
        end

    # When argument points to a directory
    when 'directory'
        Dir.chdir filename do

            # If we have ramdisk directory
            if File.directory? 'ramdisk'
                if File.exist? 'kernel'

                    # Pack the ramdisk
                    `#{TOOLS}/mkbootfs ramdisk | gzip > ramdisk-new.gz`

                    # Pack the new boot.img
                    system <<-eos
#{TOOLS}/mkbootimg --base 0x40000000 \
--kernel kernel --ramdisk ramdisk-new.gz \
--cmdline 'console=ttyS0,115200 rw init=/init loglevel=8' \
-o ../#{filename_base}.img
                eos

                    # Clean volatile
                    File.delete 'ramdisk-new.gz'
                else
                    puts "kernel not found in #{filename}"
                    exit -1
                end
            else
                puts "ramdisk directory not found in #{filename}"
                exit -1
            end
        end

    # If argument is neither a folder or a file
    else
        puts 'Incorrect argument supplied'
        exit -1
    end
end
