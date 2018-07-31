module OwnerSearch
  class Owned < Base

    def for(owner)
      # search in each marked project
      object_projects(owner).map do |project|
        find_containers(project, owner)
      end.flatten
    end

    def find_containers(rootproject, owner, devel)
      projects = rootproject.expand_all_projects(allow_remote_projects: false)

      roles = []
      filter(rootproject).each do |f|
        roles << Role.find_by_title!(f)
      end

      found_packages = Relationship.where(role_id: roles, package_id: Package.where(project_id: projects).pluck(:id))
      found_projects = Relationship.where(role_id: roles, project_id: projects)
      # fast find packages with defintions
      case owner.class
      when User
        # user in package object
        found_packages = found_packages.where(user_id: owner)
        # user in project object
        found_projects = found_projects.where(user_id: owner)
      when Group
        # group in package object
        found_packages = found_packages.where(group_id: owner)
        # group in project object
        found_projects = found_projects.where(group_id: owner)
      else
        raise ArgumentError, 'illegal object handed to find_containers'
      end
      unless devel_disabled?(project)
        # FIXME: add devel packages, but how do recursive lookup fast in SQL?
      end
      found_packages = found_packages.pluck(:package_id).uniq
      found_projects = found_projects.pluck(:project_id).uniq

      maintainers = []

      Project.where(id: found_projects).pluck(:name).each do |prj|
        maintainers << Owner.new(rootproject: rootproject.name, project: prj)
      end
      Package.where(id: found_packages).find_each do |pkg|
        maintainers << Owner.new(rootproject: rootproject.name, project: pkg.project.name, package: pkg.name)
      end

      maintainers
    end

  end
end
