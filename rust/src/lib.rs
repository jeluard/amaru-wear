use jni::sys::jstring;
use jni::objects::{JClass, JString};
use jni::JNIEnv;

mod models;
mod state;
mod amaru;
pub mod jni_impl;

#[no_mangle]
pub extern "C" fn Java_com_example_amaruwear_AmaruBridge_initLogger(
    _env: JNIEnv,
    _class: JClass,
) {
    jni_impl::init_logger();
}

#[no_mangle]
pub extern "C" fn Java_com_example_amaruwear_AmaruBridge_startNode(
    mut env: JNIEnv,
    _class: JClass,
    network: JString,
    data_dir: JString,
) -> i64 {
    let network_str: String = env.get_string(&network)
        .map(|s| s.into())
        .unwrap_or_default();
    let data_dir_str: String = env.get_string(&data_dir)
        .map(|s| s.into())
        .unwrap_or_default();
    
    jni_impl::start_node(&network_str, &data_dir_str)
}

#[no_mangle]
pub extern "C" fn Java_com_example_amaruwear_AmaruBridge_stopNode(
    _env: JNIEnv,
    _class: JClass,
) -> i64 {
    jni_impl::stop_node()
}

#[no_mangle]
pub extern "C" fn Java_com_example_amaruwear_AmaruBridge_getLatestTip(
    env: JNIEnv,
    _class: JClass,
) -> jstring {
    jni_impl::get_latest_tip_json(env)
}
