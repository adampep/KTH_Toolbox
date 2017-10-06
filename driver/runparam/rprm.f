!> @file runparam.f
!! @ingroup runparam
!! @brief Set of subroutines related to module's runtime parameters.
!! @author Adam Peplinski
!! @date Feb 5, 2017
!=======================================================================
!> @brief Initialise runtime parameters database
!! @ingroup runparam
      subroutine rprm_register
      implicit none

      include 'SIZE'
      include 'MNTRLP'
      include 'RPRMD'

!     local variables
      integer itmp
!-----------------------------------------------------------------------
!     register runtime parameter module
!     find parent module
      call mntr_mod_is_name_reg(itmp,'NEK5000')
!     register module
      call mntr_mod_reg(rprm_id,itmp,rprm_name,'Runtime parameters')
      if (itmp.le.0) then
         call mntr_log(rprm_id,lp_vrb,
     $        'ERROR: parent module ['//'NEK5000'//'] not registered')
      endif

      rprm_ifinit = .true.

      return
      end subroutine
!=======================================================================
!> @brief Register new parameter section
!! @ingroup runparam
!! @param[out] rpid     current section id
!! @param[in]  mid      registering module id
!! @param[in]  pname    section name
!! @param[in]  pdscr    section description
      subroutine rprm_sec_reg(rpid,mid,pname,pdscr)
      implicit none

      include 'SIZE'
      include 'PARALLEL'        ! ISIZE
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid
      character*(*) pname, pdscr

!     local variables
      character*10  mname
      character*20  lname
      character*132 ldscr
      character*200 llog
      integer slen,slena

      integer il, ipos
      integer lval

!     functions
      logical mntr_mod_is_id_reg
!-----------------------------------------------------------------------
!     check name length
      slena = len_trim(adjustl(pname))
!     remove trailing blanks
      slen = len_trim(pname) - slena + 1
      if (slena.gt.rprm_lstl_mnm) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long section name; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(lname,rprm_lstl_mnm)
      lname= pname(slen:slen+slena- 1)
      call capit(lname,slena)

!     check description length
      slena = len_trim(adjustl(pdscr))
!     remove trailing blanks
      slen = len_trim(pdscr) - slena + 1
      if (slena.ge.rprm_lstl_mds) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long section description; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(ldscr,rprm_lstl_mds)
      ldscr= pdscr(slen:slen + slena - 1)

!     find empty space
      ipos = 0

!     to ensure consistency I do it on master and broadcast result
      if (nid.eq.rprm_pid0) then

!     check if parameter name is already registered
         do il=1,rprm_sec_mpos
            if (rprm_sec_id(il).gt.0.and.
     $          rprm_sec_name(il).eq.lname) then
               ipos = -il
               exit
            endif
         enddo

!     find empty spot
         if (ipos.eq.0) then
            do il=1,rprm_sec_id_max
               if (rprm_sec_id(il).eq.-1) then
                  ipos = il
                  exit
               endif
            enddo
         endif
      endif

!     broadcast ipos
      call bcast(ipos,isize)

!     error; no free space found
      if (ipos.eq.0) then
         rpid = ipos
         call mntr_abort(rprm_id,
     $        'Section '//trim(lname)//' cannot be registered')
!     Section already registered
      elseif (ipos.lt.0) then
         rpid = abs(ipos)
         call mntr_abort(rprm_id,
     $    'Section '//trim(lname)//' is already registered')
!     new section
      else
         rpid = ipos
!        check if module is registered
         if (mntr_mod_is_id_reg(mid)) then
            rprm_sec_id(ipos) = mid
         else
            call mntr_abort(rprm_id,
     $          "Sections's "//trim(lname)//" module not registered")
         endif
         rprm_sec_name(ipos)=lname
         rprm_sec_dscr(ipos)=ldscr
         rprm_sec_num = rprm_sec_num + 1
         if (rprm_sec_mpos.lt.ipos) rprm_sec_mpos = ipos

!     logging
         call mntr_mod_get_info(mname,ipos,mid)
         llog='Module ['//trim(mname)//'] registered section '
         llog=trim(llog)//' '//trim(lname)//': '//trim(ldscr)
         call mntr_log(rprm_id,lp_inf,trim(llog))
      endif

      return
      end subroutine
!=======================================================================
!> @brief Check if section name is registered and return its id. Check mid as well.
!! @ingroup runparam
!! @param[out] rpid     section id
!! @param[in]  mid      registering module id
!! @param[in]  pname    section name
      subroutine rprm_sec_is_name_reg(rpid,mid,pname)
      implicit none

      include 'SIZE'
      include 'PARALLEL'        ! ISIZE
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid
      character*(*) pname

!     local variables
      character*3 str
      character*10  mname
      character*20  lname
      character*132 llog
      integer slen,slena

      integer il, ipos
!-----------------------------------------------------------------------
!     check name length
      slena = len_trim(adjustl(pname))
!     remove trailing blanks
      slen = len_trim(pname) - slena + 1
      if (slena.gt.rprm_lstl_mnm) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long section name; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(lname,rprm_lstl_mnm)
      lname= pname(slen:slen+slena- 1)
      call capit(lname,slena)

!     find parameter
      ipos = 0

!     to ensure consistency I do it on master and broadcast result
      if (nid.eq.rprm_pid0) then

!     check if parameter name is already registered
         do il=1,rprm_sec_mpos
            if (rprm_sec_id(il).gt.0.and.
     $          rprm_sec_name(il).eq.lname) then
               ipos = il
               exit
            endif
         enddo

      endif

!     broadcast ipos
      call bcast(ipos,isize)

      if (ipos.eq.0) then
         rpid = -1
         call mntr_log(rprm_id,lp_inf,
     $        'Section '//trim(lname)//' not registered')
      else
         rpid = ipos
         write(str,'(I3)') ipos
         call mntr_log(rprm_id,lp_inf,
     $   'Section '//trim(lname)//' registered with id = '//trim(str))
!     check module
         if (mid.ne.rprm_sec_id(ipos)) then
            call mntr_log(rprm_id,lp_inf,
     $      "Section's "//trim(lname)//" module inconsistent")
            rpid = -1
         endif
      endif

      return
      end subroutine
!=======================================================================
!> @brief Check if section id is registered. This operation is performed locally
!! @ingroup runparam
!! @param[in]  rpid     section id
      logical function rprm_sec_is_id_reg(rpid)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid
!-----------------------------------------------------------------------
      rprm_sec_is_id_reg = rprm_sec_id(rpid).gt.0

      return
      end function
!=======================================================================
!> @brief Get section info based on its id. This operation is performed locally
!! @ingroup runparam
!! @param[out]    pname    section name
!! @param[out]    mid      registering module id
!! @param[out]    ifact    activation flag
!! @param[inout]  rpid     section id
      subroutine rprm_sec_get_info(pname,mid,ifact,rpid)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid
      character*20 pname
      logical ifact

!     local variables
      character*5 str
!-----------------------------------------------------------------------
      if (rprm_sec_id(rpid).gt.0) then
         pname = rprm_sec_name(rpid)
         mid = rprm_sec_id(rpid)
         ifact = rprm_sec_act(rpid)
      else
         write(str,'(I3)') rpid
         call mntr_log(rprm_id,lp_inf,
     $        'Section id'//trim(str)//' not registered')
         rpid = -1
      endif

      return
      end subroutine
!=======================================================================
!> @brief Set section's activation flag. Master value is broadcasted.
!! @details This routine is added because Nek5000 uses existence of
!!    section in .par file itself as a variable, what introduces problem
!!    with their registration as sections should be registered before reading
!!    runtime parameter file. That is why I decided to split registration
!!    and activation stages. One can register all the possible sections
!!    and activate those present in .par
!! @ingroup runparam
!! @param[in]  ifact    activation flag
!! @param[in]  rpid     runtime parameter id
      subroutine rprm_sec_set_act(ifact,rpid)
      implicit none

      include 'SIZE'
      include 'PARALLEL'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid
      logical ifact

!     local variables
      logical lval
      character*5 str
!-----------------------------------------------------------------------
      if (rprm_sec_id(rpid).gt.0) then
!     broadcast pval; to keep consistency
         lval = ifact
         call bcast(lval,lsize)
         rprm_sec_act(rpid) = lval
      else
         write(str,'(I3)') rpid
         call mntr_abort(rprm_id,
     $          "Section "//trim(str)//" activation error")
      endif

      return
      end subroutine
!=======================================================================
!> @brief Check if section id is registered and activated. This operation is performed locally
!! @ingroup runparam
!! @param[in]  rpid     section id
      logical function rprm_sec_is_id_act(rpid)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid
!-----------------------------------------------------------------------
      rprm_sec_is_id_act = rprm_sec_id(rpid).gt.0.and.
     $                     rprm_sec_act(rpid)

      return
      end function
!=======================================================================
!> @brief Register new runtime parameter
!! @ingroup runparam
!! @param[out] rpid     current runtime parameter id
!! @param[in]  mid      section id
!! @param[in]  pname    parameter name
!! @param[in]  pdscr    paramerer description
!! @param[in]  ptype    parameter type
!! @param[in]  ipval    integer default value
!! @param[in]  rpval    real default value
!! @param[in]  lpval    logical default value
!! @param[in]  cpval    string default value
      subroutine rprm_rp_reg(rpid,mid,pname,pdscr,ptype ,
     $ ipval, rpval, lpval, cpval)
      implicit none

      include 'SIZE'
      include 'PARALLEL'        ! ISIZE
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid, ptype, ipval
      real rpval
      logical lpval
      character*(*) pname, pdscr, cpval

!     local variables
      character*10  mname
      character*20  lname
      character*132 ldscr
      character*200 llog
      integer slen,slena

      integer il, ipos
      integer ivall
      real rvall
      logical lvall
      character*20 cvall

!     functions
      logical rprm_sec_is_id_reg
!-----------------------------------------------------------------------
!     check name length
      slena = len_trim(adjustl(pname))
!     remove trailing blanks
      slen = len_trim(pname) - slena + 1
      if (slena.gt.rprm_lstl_mnm) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long parameter name; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(lname,rprm_lstl_mnm)
      lname= pname(slen:slen+slena- 1)
      call capit(lname,slena)

!     check description length
      slena = len_trim(adjustl(pdscr))
!     remove trailing blanks
      slen = len_trim(pdscr) - slena + 1
      if (slena.ge.rprm_lstl_mds) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long parameter description; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(ldscr,rprm_lstl_mds)
      ldscr= pdscr(slen:slen + slena - 1)

!     find empty space
      ipos = 0

!     to ensure consistency I do it on master and broadcast result
      if (nid.eq.rprm_pid0) then

!     check if parameter name is already registered
         do il=1,rprm_par_mpos
            if (rprm_par_id(rprm_par_mark,il).gt.0.and.
     $          rprm_par_name(il).eq.lname) then
               ipos = -il
               exit
            endif
         enddo

!     find empty spot
         if (ipos.eq.0) then
            do il=1,rprm_par_id_max
               if (rprm_par_id(rprm_par_mark,il).eq.-1) then
                  ipos = il
                  exit
               endif
            enddo
         endif
      endif

!     broadcast ipos
      call bcast(ipos,isize)

!     error; no free space found
      if (ipos.eq.0) then
         rpid = ipos
         call mntr_abort(rprm_id,
     $        'Parameter '//trim(lname)//' cannot be registered')
!     parameter already registered
      elseif (ipos.lt.0) then
         rpid = abs(ipos)
         call mntr_abort(rprm_id,
     $    'Parameter '//trim(lname)//' is already registered')
!     new parameter
      else
         rpid = ipos
!        check if section is registered
         if (rprm_sec_is_id_reg(mid)) then
            rprm_par_id(rprm_par_mark,ipos) = mid
         else
            call mntr_abort(rprm_id,
     $          "Parameter's "//trim(lname)//" section not registered")
         endif
         rprm_par_id(rprm_par_type,ipos) = ptype
         rprm_par_name(ipos)=lname
         rprm_par_dscr(ipos)=ldscr
         rprm_par_num = rprm_par_num + 1
         if (rprm_par_mpos.lt.ipos) rprm_par_mpos = ipos

!     broadcast pval; to keep consistency
         if (ptype.eq.rprm_par_int) then
            ivall = ipval
            call bcast(ivall,isize)
            rprm_parv_int(ipos) = ivall
         elseif (ptype.eq.rprm_par_real) then
            rvall = rpval
            call bcast(rvall,wdsize)
            rprm_parv_real(ipos) = rvall
         elseif (ptype.eq.rprm_par_log) then
            lvall = lpval
            call bcast(lvall,lsize)
            rprm_parv_log(ipos) = lvall
         elseif (ptype.eq.rprm_par_str) then
!     check value length
            slena = len_trim(adjustl(cpval))
!     remove trailing blanks
            slen = len_trim(cpval) - slena + 1
            if (slena.gt.rprm_lstl_mnm) then
               call mntr_log(rprm_id,lp_deb,
     $           'too long parameter default value; shortenning')
               slena = min(slena,rprm_lstl_mnm)
            endif
            call blank(cvall,rprm_lstl_mnm)
            cvall= cpval(slen:slen+slena- 1)
!     broadcast pval; to keep consistency
            call bcast(cvall,rprm_lstl_mnm*csize)
            rprm_parv_str(ipos) = cvall
         else
            call mntr_abort(rprm_id,
     $      "Parameter's "//trim(lname)//" wrong type")
         endif

!     logging
         mname = trim(rprm_sec_name(mid))
         llog='Section '//trim(mname)//' registered parameter '
         llog=trim(llog)//' '//trim(lname)//': '//trim(ldscr)
         call mntr_log(rprm_id,lp_inf,trim(llog))
         if (ptype.eq.rprm_par_int) then
            call mntr_logi(rprm_id,lp_inf,
     $       'Default value '//trim(lname)//' = ',ivall)
         elseif (ptype.eq.rprm_par_real) then
            call mntr_logr(rprm_id,lp_inf,
     $       'Default value '//trim(lname)//' = ',rvall)
         elseif (ptype.eq.rprm_par_log) then
            call mntr_logl(rprm_id,lp_inf,
     $       'Default value '//trim(lname)//' = ',lvall)
         elseif (ptype.eq.rprm_par_str) then
            call mntr_log(rprm_id,lp_inf,
     $       'Default value '//trim(lname)//' = '//trim(cvall))
         endif
      endif

      return
      end subroutine
!=======================================================================
!> @brief Check if parameter name is registered and return its id. Check flags as well.
!! @ingroup runparam
!! @param[out] rpid     runtime parameter id
!! @param[in]  mid      section id
!! @param[in]  pname    parameter name
!! @param[in]  ptype    parameter type
      subroutine rprm_rp_is_name_reg(rpid,mid,pname,ptype)
      implicit none

      include 'SIZE'
      include 'PARALLEL'        ! ISIZE
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid, ptype
      character*(*) pname

!     local variables
      character*3 str
      character*10  mname
      character*20  lname
      character*132 llog
      integer slen,slena

      integer il, ipos
!-----------------------------------------------------------------------
!     check name length
      slena = len_trim(adjustl(pname))
!     remove trailing blanks
      slen = len_trim(pname) - slena + 1
      if (slena.gt.rprm_lstl_mnm) then
         call mntr_log(rprm_id,lp_deb,
     $        'too long parameter name; shortenning')
         slena = min(slena,rprm_lstl_mnm)
      endif
      call blank(lname,rprm_lstl_mnm)
      lname= pname(slen:slen+slena- 1)
      call capit(lname,slena)

!     find parameter
      ipos = 0

!     to ensure consistency I do it on master and broadcast result
      if (nid.eq.rprm_pid0) then

!     check if parameter name is already registered
         do il=1,rprm_par_mpos
            if (rprm_par_id(rprm_par_mark,il).gt.0.and.
     $          rprm_par_name(il).eq.lname) then
               ipos = il
               exit
            endif
         enddo

      endif

!     broadcast ipos
      call bcast(ipos,isize)

      if (ipos.eq.0) then
         rpid = -1
         call mntr_log(rprm_id,lp_inf,
     $        'Parameter '//trim(lname)//' not registered')
      else
         rpid = ipos
         write(str,'(I3)') ipos
         call mntr_log(rprm_id,lp_inf,
     $   'Parameter '//trim(lname)//' registered with id = '//trim(str))
!     check module
         if (mid.ne.rprm_par_id(rprm_par_mark,ipos)) then
            call mntr_log(rprm_id,lp_inf,
     $      "Parameter's "//trim(lname)//" section inconsistent")
            rpid = -1
         endif
!     check type
         if (ptype.ne.rprm_par_id(rprm_par_type,ipos)) then
            call mntr_log(rprm_id,lp_inf,
     $      "Parameter's "//trim(lname)//" type inconsistent")
            rpid = -1
         endif
      endif

      return
      end subroutine
!=======================================================================
!> @brief Check if parameter id is registered and check type consistency. This operation is performed locally
!! @ingroup runparam
!! @param[in]  rpid     runtime parameter id
!! @param[in]  ptype    parameter type
      logical function rprm_rp_is_id_reg(rpid,ptype)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, ptype
!-----------------------------------------------------------------------
      rprm_rp_is_id_reg = rprm_par_id(rprm_par_mark,rpid).gt.0.and.
     $                    rprm_par_id(rprm_par_type,rpid).eq.ptype

      return
      end function
!=======================================================================
!> @brief Get parameter info based on its id. This operation is performed locally
!! @ingroup runparam
!! @param[out]    pname    parameter name
!! @param[out]    mid      section id
!! @param[out]    ptype    parameter type
!! @param[inout]  rpid     runtime parameter id
      subroutine rprm_rp_get_info(pname,mid,ptype,rpid)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, mid, ptype
      character*20 pname

!     local variables
      character*5 str
!-----------------------------------------------------------------------
      if (rprm_par_id(rprm_par_mark,rpid).gt.0) then
         pname = rprm_par_name(rpid)
         mid = rprm_par_id(rprm_par_mark,rpid)
         ptype = rprm_par_id(rprm_par_type,rpid)
      else
         write(str,'(I3)') rpid
         call mntr_log(rprm_id,lp_inf,
     $        'Parameter id'//trim(str)//' not registered')
         rpid = -1
      endif

      return
      end subroutine
!=======================================================================
!> @brief Set runtime parameter of active section. Master value is broadcasted.
!! @ingroup runparam
!! @param[in]  rpid     runtime parameter id
!! @param[in]  ptype    parameter type
!! @param[in]  ipval    integer value
!! @param[in]  rpval    real value
!! @param[in]  lpval    logical value
!! @param[in]  cpval    string value
      subroutine rprm_rp_set(rpid,ptype,ipval,rpval,lpval,cpval)
      implicit none

      include 'SIZE'
      include 'PARALLEL'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, ptype
      integer ipval
      real rpval
      logical lpval
      character*(*) cpval

!     local variables
      integer ivall
      real rvall
      logical lvall
      character*20 cvall
      character*5 str
      integer slen,slena

!-----------------------------------------------------------------------
      if (rprm_par_id(rprm_par_mark,rpid).gt.0.and.
     $    rprm_par_id(rprm_par_type,rpid).eq.ptype) then
         if(rprm_sec_act(rprm_par_id(rprm_par_mark,rpid))) then
!     broadcast pval; to keep consistency
            if (ptype.eq.rprm_par_int) then
               ivall = ipval
               call bcast(ivall,isize)
               rprm_parv_int(rpid) = ivall
            elseif (ptype.eq.rprm_par_real) then
               rvall = rpval
               call bcast(rvall,wdsize)
               rprm_parv_real(rpid) = rvall
            elseif (ptype.eq.rprm_par_log) then
               lvall = lpval
               call bcast(lvall,lsize)
               rprm_parv_log(rpid) = lvall
            elseif (ptype.eq.rprm_par_str) then
!     check value length
               slena = len_trim(adjustl(cpval))
!     remove trailing blanks
               slen = len_trim(cpval) - slena + 1
               if (slena.gt.rprm_lstl_mnm) then
                  call mntr_log(rprm_id,lp_deb,
     $           'too long parameter value; shortenning')
                  slena = min(slena,rprm_lstl_mnm)
               endif
               call blank(cvall,rprm_lstl_mnm)
               cvall= cpval(slen:slen+slena- 1)
!     broadcast pval; to keep consistency
               call bcast(cvall,rprm_lstl_mnm*csize)
               rprm_parv_str(rpid) = cvall
            else
               write(str,'(I3)') rpid
               call mntr_abort(rprm_id,
     $         "Parameter set "//trim(str)//" wrong type")
            endif
         else
            write(str,'(I3)') rpid
               call mntr_warn(rprm_id,
     $         "Parameter set "//trim(str)//" section not active")
         endif
      else
         write(str,'(I3)') rpid
         call mntr_abort(rprm_id,
     $          "Parameter "//trim(str)//" setting error")
      endif

      return
      end subroutine
!=======================================================================
!> @brief Get runtime parameter form active section. This operation is performed locally
!! @ingroup runparam
!! @param[out]  ipval    integer value
!! @param[out]  rpval    real value
!! @param[out]  lpval    logical value
!! @param[out]  cpval    string value
!! @param[in]   rpid     runtime parameter id
!! @param[in]   ptype    parameter type
      subroutine rprm_rp_get(ipval,rpval,lpval,cpval,rpid,ptype)
      implicit none

      include 'SIZE'
      include 'RPRMD'
      include 'MNTRLP'

!     argument list
      integer rpid, ptype
      integer ipval
      real rpval
      logical lpval
      character*20 cpval

!     local variables
      character*5 str
!-----------------------------------------------------------------------
      if (rprm_par_id(rprm_par_mark,rpid).gt.0.and.
     $    rprm_par_id(rprm_par_type,rpid).eq.ptype) then
         if(rprm_sec_act(rprm_par_id(rprm_par_mark,rpid))) then

            if (ptype.eq.rprm_par_int) then
               ipval = rprm_parv_int(rpid)
            elseif (ptype.eq.rprm_par_real) then
               rpval = rprm_parv_real(rpid)
            elseif (ptype.eq.rprm_par_log) then
               lpval = rprm_parv_log(rpid)
            elseif (ptype.eq.rprm_par_str) then
               cpval = rprm_parv_str(rpid)
            else
               write(str,'(I3)') rpid
               call mntr_abort(rprm_id,
     $      "Parameter get "//trim(str)//" wrong type")
            endif
         else
            write(str,'(I3)') rpid
            call mntr_warn(rprm_id,
     $         "Parameter get "//trim(str)//" section not active")
         endif
      else
         write(str,'(I3)') rpid
         call mntr_abort(rprm_id,
     $          "Parameter "//trim(str)//" getting error")
      endif

      return
      end subroutine
!=======================================================================
!> @brief Get runtime parameter from nek parser dictionary
!! @ingroup runparam
      subroutine rprm_dict_get()
      implicit none

      include 'SIZE'
      include 'PARALLEL'
      include 'RPRMD'
      include 'MNTRLP'

!     local variables
      integer il, jl, kl
      integer nkey, ifnd, i_out
      integer nmod, pmid
      character*132 key, lkey
      character*1024 val
      logical ifoundm, ifoundp, ifact
      integer itmp
      real rtmp

      character*20  lname
      character*132 ldscr
      character*200 llog
      integer slen,slena

!-----------------------------------------------------------------------
!     dictionary exists on master node only
      if (nid.eq.rprm_pid0) then
!     key number in dictionary
        call finiparser_getdictentries(nkey)

        do il=1,nkey!rprm_par_mpos

!     get a key
          call finiparser_getpair(key,val,il,ifnd)
          key = adjustl(key)
          call capit(key,132)

!     find section key belongs to
          ifoundm=.false.
          do jl=1,rprm_sec_mpos
            if (rprm_sec_id(jl).gt.0) then
              lname=trim(adjustl(rprm_sec_name(jl)))
              ifnd = index(key,trim(lname))
              if (ifnd.eq.1) then
!     set section to active
                rprm_sec_act(jl) = .true.
                ifoundm=.true.
!     looking for more than section name
                if (trim(key).ne.trim(lname)) then
!     add variable name
                  ifoundp =.false.
                  do kl=1,rprm_par_mpos
                    if (rprm_par_id(rprm_par_mark,kl).eq.jl) then
                      lkey = trim(lname)//':'//trim(rprm_par_name(kl))
                      if (trim(key).eq.trim(lkey)) then
                        ifoundp=.true.
!     read parameter value
                        if (rprm_par_id(rprm_par_type,kl).eq.
     $                      rprm_par_int) then
                          read(val,*) itmp
                          rprm_parv_int(kl) = itmp
                        elseif (rprm_par_id(rprm_par_type,kl).eq.
     $                      rprm_par_real) then
                          read(val,*) rtmp
                          rprm_parv_real(kl) = rtmp
                        elseif (rprm_par_id(rprm_par_type,kl).eq.
     $                      rprm_par_log) then
                          call finiparser_getBool(i_out,trim(lkey),ifnd)
                          if (ifnd.eq.1) then
                            if (i_out.eq.1) then
                              rprm_parv_log(kl) = .true.
                            else
                              rprm_parv_log(kl) = .false.
                            endif
                          else
                            call mntr_warn(rprm_id,
     $               'Boolean parameter reading error '//trim(key))
                          endif
                        elseif (rprm_par_id(rprm_par_type,kl).eq.
     $                      rprm_par_str) then
                          rprm_parv_str(kl) = trim(adjustl(val))
                        else
                          call mntr_warn(rprm_id,
     $               'Runtime parameter type missmatch '//trim(key))
                        endif
                        exit
                      endif
                    endif
                  enddo
!     is it unknown parameter
                  if (.not.ifoundp) then
                    call mntr_warn(rprm_id,
     $               'Unknown runtime parameter '//trim(key))
                  endif
                endif
              exit
              endif
            endif
          enddo
          if (.not.ifoundm) then
          ! possible palce for warning that section not found
          endif
        enddo
      endif

!     broadcast array data
      call bcast(rprm_parv_int,rprm_par_id_max*isize)
      call bcast(rprm_parv_real,rprm_par_id_max*wdsize)
      call bcast(rprm_parv_log,rprm_par_id_max*lsize)
      call bcast(rprm_parv_str,rprm_par_id_max*rprm_lstl_mnm*csize)

! broadcast activation lfag
      call bcast(rprm_sec_act,rprm_sec_id_max*lsize)

      return
      end subroutine
!=======================================================================
!> @brief Check consistency of module's runtime parameters
!! @ingroup runparam
!! @param[in]    mod_nkeys    number of module's keys
!! @param[in]    mod_dictkey  module's dictionary keys
!! @param[in]    mod_n3dkeys  number of keys used for 3D run only
!! @param[in]    mod_l3dkey   list of positions of 3D keys
!! @param[out]   ifsec        is section present
!! @details Check if the section name shows up and runtime parameters are
!!  spelled correctly. Give warning if section is missing, or the key is
!!  unknown. Check possible 2D - 3D parameter mismatch.
!! @warning This routine should be executed within runtime parameter reader
!!  by the master node only
      subroutine rprm_check(mod_nkeys, mod_dictkey, mod_n3dkeys,
     $           mod_l3dkey, ifsec)
      implicit none

      include 'SIZE'
      include 'INPUT'    ! IF3D

!     argument list
      integer mod_nkeys, mod_n3dkeys, mod_l3dkey(mod_n3dkeys)
      character*132 mod_dictkey(mod_nkeys)
      logical ifsec

!     local variables
      integer il, jl, ip  ! loop index
!     dictionary operations
      integer nkey, ifnd, i_out
      real d_out
      character*132 key, lkey
      character*1024 val
      logical ifvar, if3dkey
!-----------------------------------------------------------------------

!     check consistency
!     key number in dictionary
      call finiparser_getdictentries(nkey)

!     set marker for finding module's section
      ifsec = .FALSE.
      do il=1,nkey
!     get a key
         call finiparser_getpair(key,val,il,ifnd)
         call capit(key,132)

!     does it belong to current module's section
         ifnd = index(key,trim(mod_dictkey(1)))
         if (ifnd.eq.1) then
!     section was found, check variable
            ifsec = .TRUE.
            ifvar = .FALSE.
            do ip = mod_nkeys,1,-1
               lkey = trim(adjustl(mod_dictkey(1)))
               if (ip.gt.1) lkey =trim(adjustl(lkey))//
     $            ':'//trim(adjustl(mod_dictkey(ip)))
               if(index(key,trim(lkey)).eq.1) then
                  ifvar = .TRUE.
!                  exit
                  goto 20
               endif
            enddo
 20         continue
            if (ifvar) then
!     check 2D versus 3D
               if (.not.IF3D) then
                  if3dkey = .FALSE.
                  do jl=1,mod_n3dkeys
                     if (ip.eq.mod_l3dkey(jl)) then
                        if3dkey = .TRUE.
!                        exit
                        goto 40
                     endif
                  enddo
 40               continue
                  if (if3dkey) then
                     write(*,*) 'Module ',trim(mod_dictkey(1))
                     write(*,*) '3D parameter specified for 2D run'
                     write(*,*) trim(key)
                  endif
               endif
            else
!     variable not found
               write(*,*) 'Module ',trim(mod_dictkey(1))
               write(*,*) 'Unknown runtime parameter:'
               write(*,*) trim(key)
            endif
         endif
      enddo

!     no parameter section; give warning
      if (.not.ifsec) then
         write(*,*) 'Module ',trim(mod_dictkey(1))
         write(*,*) 'runtime parameter section not found.'
      endif

      return
      end subroutine
!=======================================================================
