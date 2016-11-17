require 'redmine_grack'

mount Redmine::Grack::Bundle.new, at: "git"
