require "vagrant"
require "vagrant/action/builder"
require "awesome_print"

module VagrantPlugins
  module VCloud
    module Action
      include Vagrant::Action::Builtin

      # Vagrant commands
      # This action boots the VM, assuming the VM is in a state that requires
      # a bootup (i.e. not saved).
      def self.action_boot
        Vagrant::Action::Builder.new.tap do |b|
#          b.use SetName
#          b.use ClearForwardedPorts
#          b.use Provision
#          b.use EnvSet, :port_collision_repair => true
#          b.use PrepareForwardedPortCollisionParams
#          b.use HandleForwardedPortCollisions
#          b.use ShareFolders
#          b.use ClearNetworkInterfaces
#          b.use Network
#          b.use ForwardPorts
#          b.use SetHostname
#          b.use SaneDefaults
#          b.use Customize, "pre-boot"
          b.use PowerOn
          # TODO: provision
          b.use TimedProvision
          # TODO: sync folders
          b.use SyncFolders
#          b.use Customize, "post-boot"
#          b.use CheckGuestAdditions
        end
      end



      # This action starts a VM, assuming it is already imported and exists.
      # A precondition of this action is that the VM exists.
      def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectVCloud

          b.use Call, IsRunning do |env, b2|
            # If the VM is running, then our work here is done, exit
            if env[:result]
              b2.use MessageAlreadyRunning
              next
            end
            b2.use Call, IsPaused do |env2, b3|
              if env2[:result]
                b3.use Resume
                next
              end

              # The VM is not saved, so we must have to boot it up
              # like normal. Boot!
              b3.use action_boot
            end
          end
        end
      end



      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConnectVCloud
          b.use Call, IsRunning do |env, b2|
            if !env[:result]
              b2.use MessageCannotHalt
              next
            end
            b2.use PowerOff
          end
        end
      end

      def self.action_suspend
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConnectVCloud
          b.use Call, IsRunning do |env, b2|
            # If the VM is running, must power off
            if !env[:result]
              b2.use MessageCannotSuspend
            else
              b2.use Suspend
            end
          end
        end
      end

      def self.action_resume
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConnectVCloud
          # FIXME: I don't think we need this
          #b.use InventoryCheck
          b.use Call, Resume do |env, b2|
            # nothing for now       
          end
        end
      end

      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, DestroyConfirm do |env, b2|
            if env[:result]
              b2.use ConfigValidate
              b2.use ConnectVCloud

              b2.use Call, IsRunning do |env2, b3|
              # If the VM is running, must power off
                if env2[:result]
                 b3.use PowerOff
                end
                b3.use Destroy
              end 
            else
              b2.use MessageWillNotDestroy
            end
          end
        end
      end

      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Provision
            ### TODO --- explore UNISON!
            b2.use SyncFolders
          end
        end
      end

      # This action is called to read the SSH info of the machine. The
      # resulting state is expected to be put into the `:machine_ssh_info`
      # key.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectVCloud
          b.use ReadSSHInfo
        end
      end

      # This action is called to read the state of the machine. The
      # resulting state is expected to be put into the `:machine_state_id`
      # key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectVCloud
          b.use ReadState
        end
      end

      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHRun
          end
        end
      end

      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectVCloud
          b.use InventoryCheck # Always do an inventory check

          # Handle box_url downloading early so that if the Vagrantfile
          # references any files in the box or something it all just
          # works fine.
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use HandleBoxUrl
            end
          end

          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use BuildVApp
            end
          end
          b.use action_start
          b.use ConfigureEdgeNetwork
          b.use DisconnectVCloud
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :ConnectVCloud, action_root.join("connect_vcloud")
      autoload :DisconnectVCloud, action_root.join("disconnect_vcloud")
      autoload :IsCreated, action_root.join("is_created")
      autoload :IsRunning, action_root.join("is_running")
      autoload :IsPaused, action_root.join("is_paused")
      autoload :Resume, action_root.join("resume")
      autoload :PowerOff, action_root.join("power_off")
      autoload :PowerOn, action_root.join("power_on")
      autoload :Suspend, action_root.join("suspend")
      autoload :Destroy, action_root.join("destroy")
      autoload :MessageCannotHalt, action_root.join("message_cannot_halt")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageAlreadyRunning, action_root.join("message_already_running")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :MessageCannotSuspend, action_root.join("message_cannot_suspend")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :InventoryCheck, action_root.join("inventory_check")
      autoload :BuildVApp, action_root.join("build_vapp")
      autoload :ConfigureEdgeNetwork, action_root.join("configure_edge_network")
      autoload :ReadState, action_root.join("read_state")
      autoload :SyncFolders, action_root.join("sync_folders")
      autoload :TimedProvision, action_root.join("timed_provision")
    end
  end
end

