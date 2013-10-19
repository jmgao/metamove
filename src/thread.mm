/*
 * metamove - XFree86 window movement for OS X
 * Copyright (C) 2013 jmgao
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "thread.hpp"

void set_thread_realtime(thread_port_t mach_thread_id) {
    thread_extended_policy_data_t policy;
    policy.timeshare = 0;
    thread_policy_set(
        mach_thread_id,
        THREAD_EXTENDED_POLICY,
        (thread_policy_t)&policy,
        THREAD_EXTENDED_POLICY_COUNT);

    thread_precedence_policy_data_t precedence;
    precedence.importance = 63;
    thread_policy_set(
        mach_thread_id,
        THREAD_PRECEDENCE_POLICY,
        (thread_policy_t)&precedence,
        THREAD_PRECEDENCE_POLICY_COUNT);

    const double time_quantum = 16.66666666666666666;
    const double time_needed = 0.2 * time_quantum;
    const double time_allowed = 0.85 * time_quantum;

    mach_timebase_info_data_t tb_info;
    mach_timebase_info(&tb_info);
    double ms_to_abs_time =
        ((double)tb_info.denom / (double)tb_info.numer) * 1000000;

    thread_time_constraint_policy_data_t time_constraints;
    time_constraints.period = time_quantum * ms_to_abs_time;
    time_constraints.computation = time_needed * ms_to_abs_time;
    time_constraints.constraint = time_allowed * ms_to_abs_time;
    time_constraints.preemptible = 0;

    thread_policy_set(
        mach_thread_id,
        THREAD_TIME_CONSTRAINT_POLICY,
        (thread_policy_t)&time_constraints,
        THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}
