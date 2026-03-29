set script_dir [file dirname [file normalize [info script]]]
set rtl_dir [file join $script_dir rtl]
set ip_root [file join $script_dir ip_repo dshot_target_axil]
set component_xml [file join $ip_root component.xml]

file mkdir $ip_root

proc configure_core_metadata {core} {
    set_property name dshot_target_axil $core
    set_property display_name {DSHOT Target AXI-Lite Controller} $core
    set_property description {AXI-Lite controlled DSHOT target that decodes host frames and returns an AXI-loaded reply in bidirectional mode.} $core
    set_property version 1.0 $core
    set_property core_revision 1 $core
    set_property vendor_display_name {User} $core
    set_property supported_families {artix7 Production kintex7 Production virtex7 Production zynq Production zynquplus Production spartanuplus Production} $core

    ipx::associate_bus_interfaces -busif s_axi -clock s_axi_aclk $core

    set clk_if [ipx::get_bus_interfaces s_axi_aclk -of_objects $core]
    if {[llength $clk_if] > 0} {
        set clk_param [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
        if {[llength $clk_param] == 0} {
            set clk_param [ipx::add_bus_parameter FREQ_HZ $clk_if]
        }
        set_property value 60000000 $clk_param
    }
}

create_project -in_memory dshot_target_ip_pack
add_files -norecurse [glob -nocomplain [file join $rtl_dir *.v]]
set_property top dshot_target_axil_top [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project \
    -root_dir $ip_root \
    -vendor user.org \
    -library user \
    -taxonomy /UserIP \
    -import_files \
    -set_current true

set core [ipx::current_core]
configure_core_metadata $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core
close_project

set core [ipx::open_core $component_xml]
configure_core_metadata $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
