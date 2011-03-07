#!/usr/bin/env nake
# encoding: utf-8

Task.new(:contributors) do |task|
  task.description = "Regenerate contributors file."
  task.define do
    authors = %x{git log | grep ^Author:}.split("\n")
    results = authors.reduce(Hash.new) do |results, line|
      name = line.sub(/^Author: (.+) <.+>$/, '\1')
      results[name] ||= 0
      results[name] += 1
      results
    end
    results = results.sort_by { |_, count| count }.reverse
    File.open("CONTRIBUTORS", "w") do |file|
      results.each do |name, count|
        file.puts "#{name}: #{count}"
      end
    end
  end
end
