//
//  IOKitHelpers.swift
//  StatsBar
//
//  Created by Shashank on 26/11/24.
//
//  Referenced: https://github.com/exelban/stats
//

import Foundation
import IOKit

func getIOServices(service: String) throws -> [(name: String, next: io_object_t)] {
    var result: [(name: String, next: io_object_t)] = []

    let service = IOServiceMatching(service)!
    var iter = io_iterator_t(0);
    if IOServiceGetMatchingServices(0, service, &iter) != 0 {
        print("Error: Service not found")
        throw ServiceError.matchingServiceNotFound
    }

    while case let next = IOIteratorNext(iter), next != 0 {
        var buff = [CChar](repeating: 0, count: 128)
        if IORegistryEntryGetName(next, &buff) != 0 {
            print("Error reading entry name: \(next)")
            throw ServiceError.errorReadingIORegistry
        }

        buff.withUnsafeBufferPointer { ptr in
            let data = String(cString: ptr.baseAddress!)
            result.append((name: data, next: next))
        }
    }

    return result
}

public func getIOProperties(_ entry: io_registry_entry_t) -> NSDictionary? {
    var properties: Unmanaged<CFMutableDictionary>? = nil

    if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) != kIOReturnSuccess {
        return nil
    }

    defer { properties?.release() }

    return properties?.takeUnretainedValue()
}

// https://opensource.apple.com/source/bless/bless-152/libbless/APFS/BLAPFSUtilities.c.auto.html
public func getDeviceIOParent(_ obj: io_registry_entry_t, level: Int) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0

    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }

    for _ in 1...level where IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent) != KERN_SUCCESS {
        IOObjectRelease(parent)
        return nil
    }

    return parent
}
