//
// Copyright 2010,2014 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#include "libusb1_base.hpp"
#include <uhd/transport/usb_control.hpp>
#include <boost/thread/mutex.hpp>

#include <boost/format.hpp>
#include <android/log.h>

#define ALOG(x) __android_log_print(ANDROID_LOG_VERBOSE, "uhd::libusb1_control", x);

using namespace uhd::transport;

usb_control::~usb_control(void)
{
}

/***********************************************************************
 * libusb-1.0 implementation of USB control transport
 **********************************************************************/
class libusb_control_impl : public usb_control {
public:
    libusb_control_impl(libusb::device_handle::sptr handle, const size_t interface):
        _handle(handle)
    {
      ALOG("Claiming USB interface");
      _handle->claim_interface(interface);
      ALOG("    Claimed");
    }

    ~libusb_control_impl() {
    }


    ssize_t submit(boost::uint8_t request_type,
                  boost::uint8_t request,
                  boost::uint16_t value,
                  boost::uint16_t index,
                  unsigned char *buff,
                  boost::uint16_t length,
                  boost::int32_t libusb_timeout = 0
    ){
        boost::mutex::scoped_lock lock(_mutex);
        ALOG(boost::str(boost::format("Calling libusb_control_transfer, length = %1%") \
                        % length).c_str());
        ssize_t ret = libusb_control_transfer(_handle->get(),
                                              request_type,
                                              request,
                                              value,
                                              index,
                                              buff,
                                              length,
                                              libusb_timeout);
        ALOG(boost::str(boost::format("    ret = %1%") \
                        % ret).c_str());
        return ret;
    }

private:
    libusb::device_handle::sptr _handle;
    boost::mutex _mutex;
};

/***********************************************************************
 * USB control public make functions
 **********************************************************************/
usb_control::sptr usb_control::make(usb_device_handle::sptr handle, const size_t interface){
    return sptr(new libusb_control_impl(libusb::device_handle::get_cached_handle(
        boost::static_pointer_cast<libusb::special_handle>(handle)->get_device()
    ), interface));
}
