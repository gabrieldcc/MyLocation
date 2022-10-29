//
//  Functions.swift
//  MyLocation
//
//  Created by Gabriel de Castro Chaves on 28/10/22.
//

import Foundation

func afterDelay(_ seconds: Double, run: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(
    deadline: .now() + seconds,
    execute: run)
}
