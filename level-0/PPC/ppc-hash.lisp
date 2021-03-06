;;; -*- Mode: Lisp; Package: CCL -*-
;;;
;;; Copyright 1994-2009 Clozure Associates
;;;
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.

;;; level-0;ppc;ppc-hash.lisp


(in-package "CCL")

(eval-when (:compile-toplevel :execute)
  (require "HASHENV" "ccl:xdump;hashenv"))




;;; This should stay in LAP so that it's fast
;;; Equivalent to cl:mod when both args are positive fixnums
(defppclapfunction fast-mod ((number arg_y) (divisor arg_z))
  #+ppc32-target
  (progn
    (divwu imm0 number divisor)
    (mullw arg_z imm0 divisor))
  #+ppc64-target
  (progn
    (divdu imm0 number divisor)
    (mulld arg_z imm0 divisor))
  (subf arg_z arg_z number)
  (blr))


(defppclapfunction fast-mod-3 ((number arg_x) (divisor arg_y) (recip arg_z))
  #+ppc32-target
  (progn
    (srwi imm0 number ppc32::fixnumshift)
    (mulhw imm1 imm0 recip)
    (mullw imm0 imm1 divisor))
  #+ppc64-target
  (progn
    (srdi imm0 number ppc64::fixnumshift)
    (mulhd imm1 imm0 recip)
    (mulld imm0 imm1 divisor))
  (sub number number imm0)
  (sub number number divisor)
  (srari imm0 number (1- target::nbits-in-word))
  (and divisor divisor imm0)
  (add arg_z number divisor)
  (blr))

#+ppc32-target
(defppclapfunction %dfloat-hash ((key arg_z))
  (lwz imm0 ppc32::double-float.value key)
  (lwz imm1 ppc32::double-float.val-low key)
  (add imm0 imm0 imm1)
  (box-fixnum arg_z imm0)
  (blr))

#+ppc64-target
(defppclapfunction %dfloat-hash ((key arg_z))
  (ld imm0 ppc64::double-float.value key)
  (box-fixnum arg_z imm0)
  (blr))

#+ppc32-target
(defppclapfunction %sfloat-hash ((key arg_z))
  (lwz imm0 ppc32::single-float.value key)
  (box-fixnum arg_z imm0)
  (blr))

#+ppc64-target
(defppclapfunction %sfloat-hash ((key arg_z))
  (lis imm0 #x8000)
  (srdi imm1 key 32)
  (cmpw imm0 imm1)
  (srdi arg_z key (- 32 ppc64::fixnumshift))
  (bnelr)
  (li arg_z 0)
  (blr))

(defppclapfunction %macptr-hash ((key arg_z))
  (ldr imm0 target::macptr.address key)
  (slri imm1 imm0 24)
  (add imm0 imm0 imm1)
  (clrrri arg_z imm0 target::fixnumshift)
  (blr))

#+ppc32-target
(defppclapfunction %bignum-hash ((key arg_z))
  (let ((header imm3)
        (offset imm2)
        (ndigits imm1)
        (immhash imm0))
    (li immhash 0)
    (li offset ppc32::misc-data-offset)
    (getvheader header key)
    (header-size ndigits header)
    (let ((next header))
      @loop
      (cmpwi cr0 ndigits 1)
      (subi ndigits ndigits 1)
      (lwzx next key offset)
      (addi offset offset 4)
      (rotlwi immhash immhash 13)
      (add immhash immhash next)
      (bne cr0 @loop))
    (clrrwi arg_z immhash ppc32::fixnumshift)
    (blr)))

#+ppc64-target
(defppclapfunction %bignum-hash ((key arg_z))
  (let ((header imm3)
        (offset imm2)
        (ndigits imm1)
        (immhash imm0))
    (li immhash 0)
    (li offset ppc64::misc-data-offset)
    (getvheader header key)
    (header-size ndigits header)
    (let ((next header))
      @loop
      (cmpdi cr0 ndigits 1)
      (subi ndigits ndigits 1)
      (lwzx next key offset)
      (rotldi immhash immhash 13)
      (addi offset offset 4)
      (add immhash immhash next)
      (bne cr0 @loop))
    (clrrdi arg_z immhash ppc64::fixnumshift)
    (blr)))


(defppclapfunction %get-fwdnum ()
  (ref-global arg_z target::fwdnum)
  (blr))


(defppclapfunction %get-gc-count ()
  (ref-global arg_z target::gc-count)
  (blr))


;;; Setting a key in a hash-table vector needs to 
;;; ensure that the vector header gets memoized as well
(defppclapfunction %set-hash-table-vector-key ((vector arg_x) (index arg_y) (value arg_z))
  (ba .SPset-hash-key))

(defppclapfunction %set-hash-table-vector-key-conditional ((offset 0) (vector arg_x) (old arg_y) (new arg_z))
  (ba .SPset-hash-key-conditional))

;;; Strip the tag bits to turn x into a fixnum
(defppclapfunction strip-tag-to-fixnum ((x arg_z))
  (clrlri. imm0 arg_z (- target::nbits-in-word target::fixnumshift))
  (beq @done)
  (clrrri arg_z x target::ntagbits)
  (srri arg_z arg_z (- target::ntagbits target::fixnumshift))
  @done
  (blr))

;;; end of ppc-hash.lisp
