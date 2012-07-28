#!/usr/bin/env ruby
require 'optparse'
require 'tmpdir'

opts = {
  :origin => "http://protobuf.googlecode.com/files/protobuf-2.4.1.tar.bz2",
  :sdks => [],
  :debug => false
}

opt_parser = OptionParser.new do |opt|
  opt.on("-o", "--origin", "Where to access Google's Protocol Buffers source tree") do |origin|
    opts[:origin] = origin
  end
  
  opt.on("-s", "--sdk SDK", "SDK to target") do |sdk|
    opts[:sdks] << sdk
  end
  
  opt.on("-d", "--[no-]debug", "Enable debug mode") do |debug|
    opts[:debug] = debug
  end
end

opt_parser.parse!
if opts[:sdks].length == 0
  puts opt_parser
  exit
end

def sdks
  raw_output = %x[xcodebuild -showsdks]
  raw_output.scan(/-sdk (\S+)/)
end

def sdk_paths(sdk)
  raw_output = %x[xcodebuild -version -sdk #{sdk}]
  pairs = raw_output.scan(/^([^:]+): (.+)/)
  dev_root = pairs.select {|p| p[0] == "PlatformPath"}.first
  sdk_root = pairs.select {|p| p[0] == "Path"}.first
  {:dev_root => File.join(dev_root[1], "Developer"), :sdk_root => sdk_root[1]}
end

def host_for_sdk(sdk)
  hosts = {"iphoneos5.1" => "arm-apple-darwin10", "iphonesimulator5.1" => "i686-apple-darwin11"}
  hosts[sdk]
end

def build_for_sdk(sdk)
  config_path = File.expand_path("protobuf-mirror/configure")
  build_dir = Dir.mktmpdir
  install_dir = Dir.mktmpdir
  
  puts build_dir
  puts install_dir
  
  host = host_for_sdk(sdk)
  puts host
  paths = sdk_paths(sdk)
	dp = paths[:dev_root]
	sp = paths[:sdk_root]
	
	Dir.chdir(build_dir) {|dir|
		%x[#{config_path} \
		--disable-debug \
		--disable-dependency-tracking \
		--prefix=#{install_dir} \
		--with-protoc=protoc \
		--host=#{host} \
		CC=#{dp}/usr/bin/#{host}-llvm-gcc-4.2 \
		CPP=#{dp}/usr/llvm-gcc-4.2/bin/llvm-cpp-4.2 \
		CXXCPP=#{dp}/usr/llvm-gcc-4.2/bin/llvm-cpp-4.2 \
		CXX=#{dp}/usr/bin/#{host}-llvm-g++-4.2 \
		AR=#{dp}/usr/bin/ar \
		RANLIB=#{dp}/usr/bin/ranlib \
		NM=#{dp}/usr/bin/nm  \
		CFLAGS="-isysroot #{sp}" \
		LDFLAGS="-isysroot #{sp}" \
		CXXFLAGS="-isysroot #{sp}"]
		%x[make -j8]
		%x[make install]
	}
	
	install_dir
end

def binaries
  ["libprotobuf-lite.dylib", "libprotobuf-lite.a", "libprotobuf.dylib", "libprotobuf.a"]
end

def build_lipo(sdks)
	install_paths = []
	opts[:sdks].each do |sdk| 
		install_paths << build_for_sdk(sdk)
	end
	
	%x[mkdir -p lib]
	binaries.each do |binary|
		binary_paths = install_paths.map {|p| File.join(p, "lib", binary)}.join(" ")
		%x[lipo -create #{binary_paths} -output lib/#{binary}]
	end
end

build_lipos(opts[:sdks])
